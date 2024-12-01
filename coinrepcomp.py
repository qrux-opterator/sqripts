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
    # Remove any non-numeric characters except for '.' and '-'
    cleaned_value = re.sub(r'[^\d\.-]', '', value)
    try:
        return float(cleaned_value)
    except ValueError:
        return None

def compare_values(new_value, previous_value, metric):
    """
    Compares two numerical values and returns a formatted difference string.
    Includes debug statements to output the calculation.
    """
    if new_value is not None and previous_value is not None:
        difference = new_value - previous_value
        # Debug Statement
        print(f"DEBUG: Comparing '{metric}': New Value = {new_value}, Previous Value = {previous_value}, Difference = {difference:.2f}")
        if difference > 0:
            return f"{Fore.GREEN}🟩🔼 +{difference:.2f}{Style.RESET_ALL}"
        elif difference < 0:
            return f"{Fore.RED}🟥🔽 {difference:.2f}{Style.RESET_ALL}"
        else:
            return f"{Fore.YELLOW}➖ No Change{Style.RESET_ALL}"
    # Debug Statement for non-numeric or missing values
    print(f"DEBUG: Cannot compare '{metric}'. New Value = {new_value}, Previous Value = {previous_value}")
    return f"{Fore.YELLOW}➖ N/A{Style.RESET_ALL}"

def generate_comparison_table(new_report, previous_report):
    """
    Generates a table comparing new and previous report values.
    Applies specific formatting to certain metrics.
    """
    table_data = []
    headers = ["Metric", "New Value", "Previous Value", "Difference"]

    # Define keys to compare (exclude non-numeric keys like 'Date' and 'raw')
    keys_to_compare = [key for key in new_report.keys() if key not in ['Date', 'raw']]

    for key in keys_to_compare:
        new_val_str = new_report.get(key, 'N/A')
        prev_val_str = previous_report.get(key, 'N/A')

        # Convert values, handling '%' symbol if present
        new_val_numeric = convert_value(new_val_str)
        prev_val_numeric = convert_value(prev_val_str)

        # Compare values and get the comparison string
        difference = compare_values(new_val_numeric, prev_val_numeric, key)

        # Apply formatting
        if key == 'Total QUIL earned':
            # Bold and Yellow for new value
            new_val_str = f"{Style.BRIGHT}{Fore.YELLOW}{new_val_str}{Style.RESET_ALL}"
        if key == 'Average per Worker':
            # Bold for both new and previous values
            new_val_str = f"{Style.BRIGHT}{new_val_str}{Style.RESET_ALL}"
            prev_val_str = f"{Style.BRIGHT}{prev_val_str}{Style.RESET_ALL}"

        # Append the row to table data
        table_data.append([key, new_val_str, prev_val_str, difference])

    # Create the table using tabulate with 'fancy_grid' format and left alignment
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

        # Assign each report to variables 'new' and 'previous'
        new, previous = latest_two_reports

        # Generate the comparison table
        comparison_table = generate_comparison_table(new, previous)

        # Output the formatted table
        print("\n" + comparison_table + "\n")

    except Exception as e:
        print(f"{Fore.RED}Error: {e}{Style.RESET_ALL}")

if __name__ == "__main__":
    main()
