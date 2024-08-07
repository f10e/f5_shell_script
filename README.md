backup_f5_ucs.sh

# Instructions
1. Modify the Variables:
    1. Replace your_f5_username and your_f5_password with your F5 login credentials.
    2. Set DOWNLOAD_DIR to the path where you want to save the UCS backup files.
    3. Ensure IP_LIST_FILE points to the text file containing the IP addresses of your F5 appliances (one IP address per line).

2. Ensure jq is Installed:
   The script uses jq to parse JSON responses. Install it using your package manager if you don't have it installed.

3. Create the IP List File:
   Create a text file (e.g., f5_ip_list.txt) and add the IP addresses of the F5 appliances you want to back up, one per line.

4.  Run the Script:
    1. Make the script executable: chmod +x backup_f5_ucs.sh
    2. Run the script: ./backup_f5_ucs.sh

# Notes
1. Ensure the user running the script has write permissions to the DOWNLOAD_DIR.
2. The script does not handle SSL certificate verification (-k option in curl), which is disabled for simplicity. For production use, consider adding proper certificate verification.
3. The function backup_f5 processes each F5 appliance independently and reports success or failure for each.
4. The log file will be created in the same directory as the script and will be named backup_log_<date>.log, where <date> is the date the script is run.
