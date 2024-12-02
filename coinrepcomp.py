#!/bin/bash

# Check if an argument is provided; default to 24 if not
HOURS=${1:-24}

cd /root/ceremonyclient/node

# Retrieve and process coin metadata
COIN_DATA=$(
   ./qclient-2.0.4.1-linux-amd64 token coins metadata --public-rpc --config /root/ceremonyclient/node/.config | \
awk -v hours="$HOURS" '
BEGIN {
    ENVIRON["TZ"] = "UTC"
}
{
    for(i=1; i<=NF; i++) {
        if ($i == "Timestamp") {
            ts_full = $(i+1)
            gsub("Z", "", ts_full)
            # Convert timestamp to epoch seconds using system date command
            cmd = "date -u -d \"" ts_full "\" +%s"
            cmd | getline ts_epoch
            close(cmd)
            if (ts_epoch == "") {
                # Handle parsing errors
                next
            }
            # Get current time in epoch seconds
            now_epoch = systime()
            # Calculate time difference
            diff = now_epoch - ts_epoch
            # Check if the timestamp is within the last specified hours
            if (diff >= 0 && diff <= hours * 3600) {
                print $6, $0
            }
            break
        }
    }
}' | sort | cut -d' ' -f2-
)

# Extract QUIL values and calculate total, average, median, high, and low
QUIL_VALUES=$(echo "$COIN_DATA" | awk '/QUIL/ {print $1}')
TOTAL_QUIL=$(echo "$QUIL_VALUES" | awk '{sum += $1} END {print sum}')
AVERAGE_QUIL=$(echo "$QUIL_VALUES" | awk '{sum += $1} END {if (NR > 0) print sum / NR}')
MEDIAN_QUIL=$(echo "$QUIL_VALUES" | sort -n | awk '{a[NR] = $1} END {if (NR % 2) {print a[(NR + 1) / 2]} else {print (a[(NR / 2)] + a[(NR / 2) + 1]) / 2}}')
HIGH_QUIL=$(echo "$QUIL_VALUES" | sort -n | tail -n 1)
LOW_QUIL=$(echo "$QUIL_VALUES" | sort -n | head -n 1)

# Check if /root/quileye2.log exists and retrieve Active Workers
if [ -f /root/quileye2.log ]; then
    ACTIVE_WORKERS=$(grep "Active Workers:" /root/quileye2.log | tail -n1 | awk -F'Active Workers: ' '{print $2}' | awk '{print $1}')
else
    read -p "File /root/quileye2.log not found. Enter the number of active workers: " ACTIVE_WORKERS
fi

# Calculate per worker metrics
if [ "$ACTIVE_WORKERS" -gt 0 ]; then
    TOTAL_PER_WORKER=$(awk "BEGIN {print $TOTAL_QUIL / $ACTIVE_WORKERS}")
    AVG_PER_WORKER=$(awk "BEGIN {print $AVERAGE_QUIL / $ACTIVE_WORKERS}")
    MEDIAN_PER_WORKER=$(awk "BEGIN {print $MEDIAN_QUIL / $ACTIVE_WORKERS}")
    HIGH_PER_WORKER=$(awk "BEGIN {print $HIGH_QUIL / $ACTIVE_WORKERS}")
    LOW_PER_WORKER=$(awk "BEGIN {print $LOW_QUIL / $ACTIVE_WORKERS}")
else
    TOTAL_PER_WORKER="N/A"
    AVG_PER_WORKER="N/A"
    MEDIAN_PER_WORKER="N/A"
    HIGH_PER_WORKER="N/A"
    LOW_PER_WORKER="N/A"
fi

# Calculate landing rate
LANDING_RATE=$(echo "$COIN_DATA" | awk '
/Frame / {
    n++
    match($0, /Frame ([0-9]+),/, arr)
    frame = arr[1]
    frames[n] = frame
}
END {
    asort(frames)
    first_frame = frames[1]
    last_frame = frames[n]
    frame_diff = last_frame - first_frame
    landing_rate = (frame_diff != 0) ? (n / frame_diff) * 100 : 0
    printf("%.2f", landing_rate)
}')

# Determine landing rate color
if (( $(echo "$LANDING_RATE < 5" | bc -l) )); then
    RATE_COLOR="\033[31m" # Red
elif (( $(echo "$LANDING_RATE > 10" | bc -l) )); then
    RATE_COLOR="\033[32m" # Green
else
    RATE_COLOR="" # Default
fi

# Append the report to /root/coinreport.log
{
  echo ""
  # Print Landing Rate with ANSI color
  printf "Landing Rate: \033[32m%s%%\033[0m\n" "$LANDING_RATE"
  date
  echo -e "━━━━━━━━━━━━━━━━ COINREPORT "$HOURS"hs  ━━━━━━━━━━━━━━━━"
  printf "%-25s %-20s\n" "Total QUIL earned:" "$TOTAL_QUIL"
  printf "%-25s %-20s\n" "Average QUIL per Coin:" "$AVERAGE_QUIL"
  printf "%-25s %-20s\n" "Median QUIL per Coin:" "$MEDIAN_QUIL"
  printf "%-25s %-20s\n" "High QUIL per Coin:" "$HIGH_QUIL"
  printf "%-25s %-20s\n" "Low QUIL per Coin:" "$LOW_QUIL"
  printf "%-25s %-20s\n" "Active Workers:" "$ACTIVE_WORKERS"
  printf "%-25s %-20s\n" "Total per Worker:" "$TOTAL_PER_WORKER"
  printf "%-25s %-20s\n" "Average per Worker:" "$AVG_PER_WORKER"
  printf "%-25s %-20s\n" "Median per Worker:" "$MEDIAN_PER_WORKER"
  printf "%-25s %-20s\n" "High per Worker:" "$HIGH_PER_WORKER"
  printf "%-25s %-20s\n" "Low per Worker:" "$LOW_PER_WORKER"
  printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
} >> /root/coinreport.log

# Display the content of the log file
cat /root/coinreport.log
root@server:~# ^C
root@server:~# pip install tabulate ; wget -O /root/coinrepcomp.py https://raw.githubusercontent.com/qrux-opterator/sqripts/refs/heads/main/coinrepcomp.py && python3 /root/coinrepcomp.pyc^C
root@server:~# cat /root/coinrepcomp.py
import os
import re
from tabulate import tabulate
from colorama import init, Fore, Style

# Initialize colorama for cross-platform compatibility
init(autoreset=True)

def is_separator_line(line):
    """
    Determines if a line is a separator (composed entirely of '━' characters) or empty.
    """
    stripped_line = line.strip()
    return all(c == '━' for c in stripped_line) or not stripped_line

def parse_report(report_lines):
    """
    Parses a single report and returns a dictionary of key-value pairs.
    Prevents overwriting existing keys to ensure original values are retained.
    """
    data = {}
    if not report_lines:
        return data

    # Extract the "COINREPORT Xhs" line and extract the number
    coinreport_line = next((line for line in report_lines if "COINREPORT" in line), None)
    if coinreport_line:
        match = re.search(r"COINREPORT (\d+)hs", coinreport_line)
        if match:
            data['Check'] = match.group(1)

    # First line is 'Landing Rate: XX.XX%'
    line = report_lines[0]
    if line.startswith('Landing Rate:'):
        landing_rate = line[len('Landing Rate:'):].strip()
        data['Landing Rate'] = landing_rate

    # Second line is the date
    if len(report_lines) > 1:
        date_line = report_lines[1]
        data['Date'] = date_line.strip()

    # Process the rest of the lines
    for line in report_lines[2:]:
        line = line.strip()
        if is_separator_line(line):
            continue
        elif ':' in line:
            key_value = line.split(':', 1)
            key = key_value[0].strip()
            value = key_value[1].strip()
            # Prevent overwriting existing keys
            if key not in data:
                data[key] = value
    return data

def get_latest_reports(file_path, number_of_reports=2):
    """
    Reads the log file and retrieves the latest 'number_of_reports' reports.
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"The file {file_path} does not exist.")

    with open(file_path, 'r') as f:
        lines = f.readlines()

    reports = []
    current_report = []

    for line in lines:
        line = line.rstrip('\n')
        if line.startswith('Landing Rate:'):
            if current_report:
                reports.append(current_report)
                current_report = []
        current_report.append(line)
    if current_report:
        reports.append(current_report)

    if len(reports) < number_of_reports:
        raise ValueError(f"Only {len(reports)} report(s) found, but {number_of_reports} requested.")

    # Get the last 'number_of_reports' reports
    latest_reports = reports[-number_of_reports:]

    # Parse the reports into dictionaries
    parsed_reports = [parse_report(report) for report in latest_reports]

    return parsed_reports

def convert_value(value):
    """
    Converts a string to a float, removing any non-numeric characters like '%'.
    Returns the number as a float. If conversion fails, returns None.
    """
    if value is None:
        return None
    # Remove any non-numeric characters except for '.' and '-'
    cleaned_value = re.sub(r'[^\d\.-]', '', value)
    try:
        return float(cleaned_value)
    except ValueError:
        return None

def compare_values(new_value, previous_value, metric):
    """
    Compares two numerical values and returns a formatted difference string.
    """
    if new_value is not None and previous_value is not None:
        difference = new_value - previous_value
        if difference > 0:
            return f"{Fore.GREEN}🟩🔼 +{difference:.2f}{Style.RESET_ALL}"
        elif difference < 0:
            return f"{Fore.RED}🟥🔽 {difference:.2f}{Style.RESET_ALL}"
        else:
            return f"{Fore.YELLOW}➖ No Change{Style.RESET_ALL}"
    return f"{Fore.YELLOW}➖ N/A{Style.RESET_ALL}"

def generate_comparison_table(new_report, previous_report):
    """
    Generates a table comparing new and previous report values.
    Applies specific formatting to certain metrics.
    """
    table_data = []
    headers = ["Metric", "Last Check", "Previous Check", "Difference"]

    # Get the check numbers (timeframes)
    last_check = new_report.get('Check', 'N/A')
    previous_check = previous_report.get('Check', 'N/A')

    # Map 'Check' numbers to timeframes
    timeframe_mapping = {'2': '2 Hours', '24': '24 Hours'}
    last_timeframe = timeframe_mapping.get(last_check, last_check)
    previous_timeframe = timeframe_mapping.get(previous_check, previous_check)

    # Change 'Check' row to 'Timeframe' and update values
    table_data.append(['Timeframe', last_timeframe, previous_timeframe, '22 Hours'])

    # Define the keys to compare
    keys_to_compare = [key for key in new_report.keys() if key not in ['Date', 'raw', 'Check']]

    for key in keys_to_compare:
        new_val_str = new_report.get(key, 'N/A')
        prev_val_str = previous_report.get(key, 'N/A')

        # Convert values to numeric types
        new_val_numeric = convert_value(new_val_str)
        prev_val_numeric = convert_value(prev_val_str)

        # For 'Total QUIL earned' and 'Total per Worker', normalize values
        if key in ['Total QUIL earned', 'Total per Worker']:
            # Normalize values to 22 hours
            try:
                last_hours = int(re.sub(r'[^\d]', '', last_timeframe))
                prev_hours = int(re.sub(r'[^\d]', '', previous_timeframe))
                new_normalized = new_val_numeric * (22 / last_hours) if new_val_numeric is not None else None
                prev_normalized = prev_val_numeric * (22 / prev_hours) if prev_val_numeric is not None else None
                # Use normalized values for comparison
                difference = compare_values(new_normalized, prev_normalized, key)
                # Display normalized values in parentheses
                if new_normalized is not None:
                    new_val_str += f" ({new_normalized:.2f})"
                if prev_normalized is not None:
                    prev_val_str += f" ({prev_normalized:.2f})"
            except (ValueError, ZeroDivisionError):
                # In case of invalid timeframe, fall back to original values
                difference = compare_values(new_val_numeric, prev_val_numeric, key)
        else:
            # Use original values for comparison
            difference = compare_values(new_val_numeric, prev_val_numeric, key)

        # Apply formatting
        if key == 'Total QUIL earned':
            new_val_str = f"{Style.BRIGHT}{Fore.YELLOW}{new_val_str}{Style.RESET_ALL}"
        if key == 'Average per Worker':
            new_val_str = f"{Style.BRIGHT}{new_val_str}{Style.RESET_ALL}"
            prev_val_str = f"{Style.BRIGHT}{prev_val_str}{Style.RESET_ALL}"

        # Append the row to table data
        table_data.append([key, new_val_str, prev_val_str, difference])

    # Create the table using tabulate
    table = tabulate(
        table_data,
        headers=headers,
        tablefmt="fancy_grid",
        stralign="left",
        numalign="left"
    )
    return table

def main():
    file_path = 'coinreport.log'  # Ensure this path is correct
    try:
        # Retrieve the latest two reports
        latest_two_reports = get_latest_reports(file_path, 2)

        # Assign each report to variables 'new' and 'previous' (swapped)
        previous, new = latest_two_reports  # Swapped the order

        # Generate the comparison table
        comparison_table = generate_comparison_table(new, previous)

        # Output the formatted table
        print("\n" + comparison_table + "\n")

    except Exception as e:
        print(f"{Fore.RED}Error: {e}{Style.RESET_ALL}")

if __name__ == "__main__":
    main()
