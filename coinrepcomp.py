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
