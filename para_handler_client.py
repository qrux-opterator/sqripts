#!/usr/bin/python3
import subprocess
import time
from datetime import datetime
import select
import logging

log_file_path = "/root/para_crash.log"

# Configure logging using Python's logging module for better management
logging.basicConfig(
    filename=log_file_path,
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

# Function to log events with the option to log an error
def log_event(event_message, error=False):
    if error:
        logging.error(event_message)
        print(f"[DEBUG] ERROR: {event_message}")
    else:
        logging.info(f"Machine running: {event_message}")
        print(f"[DEBUG] Machine running: {event_message}")

# Function to log service restarts
def log_restart():
    restart_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    logging.info(f"Para.sh was offline - restarted at: {restart_time}")
    print(f"[DEBUG] Service restarted at: {restart_time}")

# Function to restart the service
def restart_service():
    print("[DEBUG] Restarting service...")
    logging.info("Restarting service...")
    try:
        # Terminate the specific process
        subprocess.run(["pkill", "-f", "node-1.4.21.1-linux"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        print("[DEBUG] Terminated node-1.4.21.1-linux process.")
        logging.info("Terminated node-1.4.21.1-linux process.")
    except subprocess.CalledProcessError as e:
        log_event(f"Failed to terminate process: {e}", error=True)
        print("[DEBUG] Failed to terminate node-1.4.21.1-linux process.")

    # Log the restart event
    log_restart()

    try:
        # Restart the para service
        subprocess.run(["service", "para", "restart"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        print("[DEBUG] Restarted para service.")
        logging.info("Restarted para service.")
    except subprocess.CalledProcessError as e:
        log_event(f"Failed to restart para service: {e}", error=True)
        print("[DEBUG] Failed to restart para service.")

# Function to check the last 20 logs for errors or confirmation
def check_old_logs():
    print("[DEBUG] Entered check_old_logs function.")
    logging.debug("Starting check_old_logs.")
    try:
        process = subprocess.Popen(
            ["journalctl", "-u", "para.service", "--no-hostname", "-n", "20"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True
        )
    except Exception as e:
        log_event(f"Failed to execute journalctl: {e}", error=True)
        restart_service()
        return True  # Indicates that a restart was performed

    found_error_or_panic = False
    found_data_worker_listening = False

    while True:
        line = process.stdout.readline()
        if not line:
            break
        line = line.strip()
        logging.debug(f"Old log line: {line}")
        print(f"[DEBUG] Old log line: {line}")

        # Check if "data worker listening" is found
        if "data worker listening" in line.lower():
            log_event(line)
            logging.debug('Found "data worker listening" in old logs.')
            found_data_worker_listening = True

        # Check if "error" or "panic" is found
        if "error" in line.lower() or "panic" in line.lower():
            log_event(line, error=True)
            logging.debug('Found "error" or "panic" in old logs.')
            found_error_or_panic = True

    # Apply logic based on findings
    if found_error_or_panic:
        logging.debug("Found error or panic. Restarting service...")
        print("[DEBUG] Found error or panic in old logs. Restarting service...")
        restart_service()
        return True
    elif not found_data_worker_listening:
        logging.debug('"data worker listening" not found in old logs. Restarting service...')
        print('[DEBUG] "data worker listening" not found in old logs. Restarting service...')
        restart_service()
        return True
    else:
        logging.debug('No errors or panic found, and "data worker listening" was present. No restart needed.')
        print('[DEBUG] No errors or panic found, and "data worker listening" was present. No restart needed.')
        return False

# Function to monitor logs in real-time for errors or panics
def monitor_journal():
    print("[DEBUG] Entered monitor_journal function.")
    logging.debug("Starting monitor_journal.")
    try:
        process = subprocess.Popen(
            ["journalctl", "-u", "para.service", "--no-hostname", "-n", "20", "-f"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True
        )
    except Exception as e:
        log_event(f"Failed to execute journalctl for monitoring: {e}", error=True)
        restart_service()
        return

    end_time = time.time() + 30  # Monitor for 30 seconds
    last_log_time = time.time()
    found_error_or_panic = False
    print("[DEBUG] Monitoring logs for 30 seconds...")
    logging.debug("Monitoring logs for 30 seconds...")

    try:
        while time.time() < end_time:
            remaining_time = int(end_time - time.time())
            print(f"[DEBUG] Time remaining: {remaining_time} seconds")
            logging.debug(f"Time remaining: {remaining_time} seconds")
            ready, _, _ = select.select([process.stdout], [], [], 0.5)

            if ready:
                line = process.stdout.readline()
                if not line:
                    continue
                line = line.strip()
                if not line:
                    continue
                logging.debug(f"Log line read: {line}")
                print(f"[DEBUG] Log line read: {line}")

                # Check for panic or error
                if "panic:" in line.lower() or "error" in line.lower():
                    log_event(line, error=True)
                    logging.debug('Found "panic:" or "error". Restarting service...')
                    print('[DEBUG] Found "panic:" or "error". Restarting service...')
                    process.terminate()
                    restart_service()
                    return

            else:
                print("[DEBUG] No new log entries detected")
                logging.debug("No new log entries detected")

            # Optional: Check if no new log entries for a while
            if time.time() - last_log_time > 5:
                print("[DEBUG] No new log entries detected for 5 seconds")
                logging.debug("No new log entries detected for 5 seconds")
                last_log_time = time.time()

        # After timeout, do not check for "data worker listening"
        logging.debug("Monitoring timeout reached. No errors or panics detected. No action needed.")
        print("[DEBUG] Monitoring timeout reached. No errors or panics detected. No action needed.")

    except KeyboardInterrupt:
        process.terminate()
        logging.info("Monitoring interrupted by user.")
        print("[DEBUG] Monitoring interrupted by user.")

if __name__ == "__main__":
    print("[DEBUG] Script started.")
    logging.debug("Script started.")
    should_restart = check_old_logs()
    if not should_restart:
        monitor_journal()
    print("[DEBUG] Script finished.")
    logging.debug("Script finished.")
