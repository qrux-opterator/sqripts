import re
from wcwidth import wcswidth

# ANSI-Escape-Codes für Farben und Stil
RESET = "\033[0m"
BOLD = "\033[1m"

# Farben
GREEN = "32"
YELLOW = "33"  # Für hellorange
RED = "31"
CYAN = "36"
BLUE = "34"

def color_text(text, color=None, bold=False):
    """
    Funktion zum Einfärben und Formatieren von Text.
    """
    codes = []
    if bold:
        codes.append("1")
    if color:
        codes.append(color)
    if codes:
        color_code = "\033[" + ";".join(codes) + "m"
        return f"{color_code}{text}{RESET}"
    else:
        return text

def strip_ansi_codes(text):
    """
    Entfernt ANSI-Escape-Sequenzen aus einem Text.
    """
    ansi_escape = re.compile(r'\x1B\[[0-?]*[ -/]*[@-~]')
    return ansi_escape.sub('', text)

def parse_check(lines, check_nr):
    """
    Parsen eines spezifischen Check-Nr Abschnitts aus den Logzeilen.
    """
    check_pattern = f"Check-Nr {check_nr}:"
    start_index = next((i for i, line in enumerate(lines) if check_pattern in strip_ansi_codes(line)), None)
    if start_index is not None:
        relevant_lines = lines[start_index : start_index + 4]
        check_data = {}
        for line in relevant_lines:
            stripped_line = strip_ansi_codes(line)
            if "Max Frame:" in stripped_line:
                match = re.search(r"Max Frame: (\d+)", stripped_line)
                if match:
                    check_data["Max Frame"] = int(match.group(1))
            if "Prover Ring:" in stripped_line:
                match = re.search(r"Prover Ring: ([+-]?\d+)", stripped_line)
                if match:
                    check_data["Prover Ring"] = int(match.group(1))
            if "Seniority:" in stripped_line:
                match = re.search(r"Seniority: (\d+)", stripped_line)
                if match:
                    check_data["Seniority"] = int(match.group(1))
            if "Coins:" in stripped_line:
                match = re.search(r"Coins: (\d+)", stripped_line)
                if match:
                    check_data["Coins"] = int(match.group(1))
            if "Owned balance:" in stripped_line:
                match = re.search(r"Owned balance: ([\d.]+) QUIL", stripped_line)
                if match:
                    check_data["Owned balance"] = round(float(match.group(1)), 3)
            if "Proofs" in stripped_line:
                match = re.search(r"(\d+) Proofs", stripped_line)
                if match:
                    check_data["Proofs"] = int(match.group(1))
            if "Creation:" in stripped_line:
                match = re.search(r"Creation: ([+-]?\d+(\.\d+)*)s", stripped_line)
                if match:
                    check_data["Creation"] = float(match.group(1))
            if "Submission:" in stripped_line:
                match = re.search(r"Submission: ([+-]?\d+(\.\d+)*)s", stripped_line)
                if match:
                    check_data["Submission"] = float(match.group(1))
            if "CPU-Processing:" in stripped_line:
                match = re.search(r"CPU-Processing: ([+-]?\d+(\.\d+)*)s", stripped_line)
                if match:
                    check_data["CPU-Processing"] = float(match.group(1))
        return check_data, "".join(relevant_lines)
    return None, None

def calculate_changes(user_data, auto_data):
    """
    Berechnet die Änderungen zwischen UserCheck und AutoCheck.
    Rundet bestimmte Schlüssel auf zwei Dezimalstellen und fügt Einheiten hinzu.
    """
    changes = []
    for key in user_data:
        if key in auto_data:
            difference = auto_data[key] - user_data[key]
            if difference != 0:
                # Definiere Schlüssel, die auf zwei Dezimalstellen gerundet werden sollen
                keys_with_two_decimals = ["Submission", "CPU-Processing", "Creation"]
                
                if key in keys_with_two_decimals:
                    difference_str = f"{difference:+.2f}s"
                elif key == "Owned balance":
                    difference_str = f"{difference:+.3f}"
                else:
                    difference_str = f"{difference:+}"
                changes.append(f"{key}: {difference_str}")
    return " - ".join(changes)

def display_menu(title, content):
    """
    Zeigt den Inhalt in einem eingerahmten Menü an.
    Berechnet die tatsächliche Anzeigebreite unter Berücksichtigung von Emojis.
    """
    content_lines = content.splitlines()
    # Berechne die sichtbaren Längen der Inhaltszeilen (ohne ANSI-Codes)
    content_lengths = [wcswidth(strip_ansi_codes(line)) for line in content_lines]

    # Berechne die sichtbare Länge des Titels (ohne ANSI-Codes)
    title_stripped = strip_ansi_codes(title)
    title_length = wcswidth(title_stripped)

    # Berechne die maximale sichtbare Zeilenlänge
    max_line_length = max([title_length] + content_lengths) if content_lengths else title_length

    padding = 2  # 1 Leerzeichen auf jeder Seite
    width = max_line_length + padding

    # Erstelle den Rahmen und die Zeilen
    border = f"╔{'═' * width}╗"

    # Berechne das linke und rechte Padding für das Zentrieren des Titels
    total_padding = width - 2 - title_length
    left_padding = total_padding // 2
    right_padding = total_padding - left_padding
    header = f"║ {' ' * left_padding}{title}{' ' * right_padding} ║"

    body_lines = []
    for line in content_lines:
        stripped_line = strip_ansi_codes(line)
        line_width = wcswidth(stripped_line)
        padding_needed = width - 2 - line_width
        body_lines.append(f"║ {line}{' ' * padding_needed} ║")

    body = "\n".join(body_lines)
    footer = f"╚{'═' * width}╝"

    return f"{border}\n{header}\n{body}\n{footer}"

def format_owned_balance(line):
    """
    Formatiert die Owned balance in den Detailzeilen.
    Entfernt die Einheit 'QUIL' zur Vermeidung von Ausrichtungsproblemen.
    """
    match = re.search(r"Owned balance: ([\d.]+) QUIL", line)
    if match:
        original_balance = float(match.group(1))
        rounded_balance = f"{original_balance:.3f}"
        return re.sub(r"Owned balance: [\d.]+ QUIL", f"Owned balance: {rounded_balance}", line)
    return line

def format_changes(changes):
    """
    Formatiert die Änderungen mit Farben und Fettdruck basierend auf den Regeln.
    """
    change_pairs = changes.split(" - ")
    formatted_pairs = []
    for pair in change_pairs:
        if ": " in pair:
            key, value = pair.split(": ", 1)
            # Bestimme die Farbe basierend auf Schlüssel und Wert
            try:
                # Entfernt das 's' für Sekunden bei bestimmten Werten
                numeric_value = float(strip_ansi_codes(re.sub(r's$', '', value)))
            except ValueError:
                numeric_value = 0.0  # Standardwert, wenn Umwandlung fehlschlägt
            if key == "Prover Ring":
                if numeric_value > 0:
                    formatted_value = color_text(value, GREEN, bold=True)
                elif numeric_value < 0:
                    formatted_value = color_text(value, CYAN, bold=False)
                else:
                    formatted_value = value  # Keine Farbe
            elif key == "Seniority":
                if numeric_value > 0:
                    formatted_value = color_text(value, YELLOW, bold=True)
                elif numeric_value < 0:
                    formatted_value = color_text(value, RED, bold=True)
                else:
                    formatted_value = value  # Keine Farbe
            else:
                if numeric_value > 0:
                    formatted_value = color_text(value, GREEN, bold=True)
                elif numeric_value < 0:
                    formatted_value = color_text(value, RED, bold=True)
                else:
                    formatted_value = value  # Keine Farbe
            formatted_pairs.append(f"{key}: {formatted_value}")
    return " - ".join(formatted_pairs)

def color_proofs_line(line):
    """
    Formatiert die "Proofs"-Zeile mit Farben.
    """
    # Beispielzeile:
    # "108 Proofs - Creation: 29.10s - Submission: 41.05s - CPU-Processing: 11.95s"
    # Farben:
    # - Creation: Zahl in Gelb und Fett
    # - Submission: Zahl in Gelb und Fett
    # - CPU-Processing: Zahl in Grün und Fett
    def replace_creation(match):
        number = float(match.group(1))
        rounded = f"{number:+.2f}"
        return f"Creation: {color_text(rounded, YELLOW, bold=True)}s"

    def replace_submission(match):
        number = float(match.group(1))
        rounded = f"{number:+.2f}"
        return f"Submission: {color_text(rounded, YELLOW, bold=True)}s"

    def replace_cpu(match):
        number = float(match.group(1))
        rounded = f"{number:+.2f}"
        return f"CPU-Processing: {color_text(rounded, GREEN, bold=True)}s"

    line = re.sub(r'Creation: ([+-]?\d+(\.\d+)*)s', replace_creation, line)
    line = re.sub(r'Submission: ([+-]?\d+(\.\d+)*)s', replace_submission, line)
    line = re.sub(r'CPU-Processing: ([+-]?\d+(\.\d+)*)s', replace_cpu, line)
    return line

def bold_numbers(line):
    """
    Fettgedruckt alle Zahlen in einer Zeile.
    """
    return re.sub(r'(\d+(\.\d+)?)', lambda m: color_text(m.group(1), None, bold=True), line)

def create_special_event_message(prover_ring_diff):
    """
    Erstellt die spezielle Ereignismeldung basierend auf der Differenz des Prover Rings.
    """
    absolute_value = abs(prover_ring_diff)
    if prover_ring_diff < 0:
        # Negative Differenz: Prover Ring geklettert
        special_event_title = color_text("SPECIAL EVENT:", YELLOW, bold=True)
        climb_message = f"🎉🎉🎉You climbed {color_text(str(absolute_value), None, bold=True)} Prover Ring 🎉🎉🎉"
        well_done_message = color_text("👏 Well done! 🍻", GREEN)
        content = f"{climb_message}\n{well_done_message}"
    elif prover_ring_diff > 0:
        # Positive Differenz: Prover Ring gefallen
        special_event_title = color_text("SPECIAL EVENT:", YELLOW, bold=True)
        fall_message = f"😔 You fell {color_text(str(absolute_value), None, bold=True)} Prover Ring. Sorry. It's not the End. I hope you climb back quick 🤞🫂"
        content = f"{fall_message}"
    else:
        return None  # Keine Meldung bei null Differenz

    return display_menu(special_event_title, content)

def main():
    log_file_path = "/root/quileye2.log"  # Pfad zur Logdatei

    try:
        with open(log_file_path, 'r') as log_file:
            log_content_colored = log_file.readlines()
            log_content_stripped = [strip_ansi_codes(line) for line in log_content_colored]
    except FileNotFoundError:
        print(f"Error: Logdatei '{log_file_path}' nicht gefunden.")
        return

    # Extrahiere LastUserCheck und LastAutoCheck
    last_user_check = None
    last_auto_check = None
    for line in log_content_stripped:
        if line.startswith("LastUserCheck:"):
            last_user_check = int(line.split(":")[1].strip())
        elif line.startswith("LastAutoCheck:"):
            last_auto_check = int(line.split(":")[1].strip())

    if last_user_check is None or last_auto_check is None:
        print("Error: LastUserCheck oder LastAutoCheck nicht in der Logdatei gefunden.")
        return

    # Berechne die Differenz zwischen AutoCheck und UserCheck
    autocheck_difference = last_auto_check - last_user_check

    # Parse die Daten für beide Checks
    user_data, user_lines = parse_check(log_content_stripped, last_user_check)
    auto_data, auto_lines = parse_check(log_content_stripped, last_auto_check)

    if user_data is None or auto_data is None:
        print("Error: Daten für die angegebenen Checks in der Logdatei nicht gefunden.")
        return

    # Berechne Änderungen
    changes = calculate_changes(user_data, auto_data)

    # Formatiere die Änderungen mit Farben
    formatted_changes = format_changes(changes)

    # Spezifische Prover Ring Differenz extrahieren
    prover_ring_diff = auto_data.get("Prover Ring", 0) - user_data.get("Prover Ring", 0)

    # Erstelle und zeige die spezielle Ereignismeldung, wenn die Prover Ring Differenz nicht null ist
    if prover_ring_diff != 0:
        special_event_menu = create_special_event_message(prover_ring_diff)
        if special_event_menu:
            print(special_event_menu)

    # Anzeige des Änderungsmenüs
    title_changes = f"Change since {autocheck_difference} Autochecks:"
    menu_changes = display_menu(title_changes, formatted_changes)
    print(menu_changes)

    # Formatierung der AutoCheck Details für das zweite Menü
    auto_lines_formatted = "\n".join(
        format_owned_balance(line.strip()) for line in auto_lines.splitlines()
    )

    # Bereite die neuen Titelzeile vor
    auto_lines_cleaned = auto_lines_formatted.splitlines()

    if len(auto_lines_cleaned) >= 4:
        # Erwartete Struktur:
        # Line 0: "Check-Nr X:"
        # Line 1: "Peer ID: ... - Date: ..."
        # Line 2: "Max Frame: ... - Active Workers: ... - Prover Ring: ... - Seniority: ... - Coins: ... - Owned balance: ... QUIL"
        # Line 3: "XXX Proofs - Creation: ... - Submission: ... - CPU-Processing: ..."

        # Neuer Titel mit Farben
        new_title = f"{color_text('Last Node Check:', YELLOW, bold=True)} - Check-Nr {color_text(f'{last_auto_check}:', BLUE, bold=False)}"

        # Inhaltzeilen:
        peer_date_line = auto_lines_cleaned[1]
        max_frame_line = auto_lines_cleaned[2]
        proofs_line = auto_lines_cleaned[3]

        # Fettgedruckt alle Zahlen in der Max Frame Zeile
        max_frame_line_bold = bold_numbers(max_frame_line)

        # Farbige Proofs Zeile
        proofs_line_colored = color_proofs_line(proofs_line)

        # Kombiniere die Inhaltzeilen
        new_content_lines = [peer_date_line, max_frame_line_bold, proofs_line_colored]
    else:
        # Fallback, falls die Zeilenstruktur nicht wie erwartet ist
        new_title = f"Last Node Check: - Check-Nr {last_auto_check}:"
        new_content_lines = auto_lines_cleaned

    # Anzeige des "Last Node Check" Menüs
    new_content = "\n".join(new_content_lines)
    last_node_check_menu = display_menu(new_title, new_content)
    print(last_node_check_menu)

if __name__ == "__main__":
    main()
