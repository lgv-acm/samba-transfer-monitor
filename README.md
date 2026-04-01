# Samba Transfer Monitor

A Bash script to benchmark and monitor upload/download transfer speeds to and from a Samba (SMB/CIFS) server using `smbclient`. Results are logged to a CSV file so you can build a performance history over time.

## Prerequisites

- Linux (any reasonably recent distribution)
- [`smbclient`](https://www.samba.org/samba/docs/current/man-html/smbclient.1.html) — install with:
  ```bash
  sudo apt install smbclient      # Ubuntu/Debian
  sudo dnf install samba-client   # Fedora/RHEL
  ```
- `dd` — standard on all Linux systems
- `bc` — install with:
  ```bash
  sudo apt install bc             # Ubuntu/Debian
  sudo dnf install bc             # Fedora/RHEL
  ```

## Setup and Configuration

1. **Clone this repository** (or download the script):
   ```bash
   git clone https://github.com/lgv-acm/samba-transfer-monitor.git
   cd samba-transfer-monitor
   ```

2. **Edit `monitor_samba_speed.sh`** and set the configuration variables at the top of the file:

   | Variable       | Description                                              | Example                  |
   |----------------|----------------------------------------------------------|--------------------------|
   | `SERVER`       | Hostname or IP address of your Samba server              | `192.168.1.100`          |
   | `SHARE`        | Name of the Samba share                                  | `shared`                 |
   | `USER`         | Samba username                                           | `alice`                  |
   | `PASSWORD`     | Samba password                                           | `secret`                 |
   | `LOCAL_TMP`    | Local directory for temporary test files                 | `/tmp/samba_speed_test_local` |
   | `REMOTE_TMP`   | Directory on the share where tests run (must be writable)| `speedtest`              |
   | `FILE_SIZE_MB` | Size of the test file in MB                              | `10`                     |
   | `OUTPUT_FILE`  | Path of the output CSV log file                          | `samba_transfer_history.csv` |

3. **Make the script executable** (if it isn't already):
   ```bash
   chmod +x monitor_samba_speed.sh
   ```

4. **Create the remote directory** on your Samba share if it does not already exist:
   ```bash
   smbclient //your-server/your-share -U username%password -c "mkdir speedtest"
   ```

## Usage

Run the script manually:
```bash
./monitor_samba_speed.sh
```

The script will:
1. Generate a random local test file of the configured size.
2. **Upload** the file to the Samba share and measure the transfer speed.
3. **Download** the file back and measure the transfer speed.
4. Append both results as rows in the CSV log file.
5. Clean up all temporary files (local and remote).

The CSV header is written only when the output file is first created. Subsequent runs append new rows.

## Sample Output

After a few runs, `samba_transfer_history.csv` will look like:

```
timestamp,operation,filesize_MB,duration_sec,speed_MBps
2026-04-01 09:00:21,upload,10,1.11,9.01
2026-04-01 09:00:23,download,10,1.04,9.62
2026-04-01 10:00:18,upload,10,1.08,9.25
2026-04-01 10:00:20,download,10,1.02,9.80
```

| Column         | Description                          |
|----------------|--------------------------------------|
| `timestamp`    | Date and time the test was run       |
| `operation`    | `upload` or `download`               |
| `filesize_MB`  | Size of the test file in MB          |
| `duration_sec` | Transfer duration in seconds         |
| `speed_MBps`   | Calculated speed in MB/s             |

## Optional: Schedule with Cron

To run the monitor automatically (e.g., every hour), add it to your crontab:

```bash
crontab -e
```

Add a line like:
```
0 * * * * /path/to/samba-transfer-monitor/monitor_samba_speed.sh
```

Use an absolute path for `OUTPUT_FILE` in the script when running via cron, so the log is always written to the same location regardless of the working directory.

## Security Warning

> ⚠️ **Warning:** Storing credentials (username and password) in plain text inside a script is insecure.  
> For production or shared systems, consider these safer alternatives:
>
> - **Use a `.smbcredentials` file** with restricted permissions (`chmod 600`) and reference it with the `--authentication-file` option of `smbclient`.
> - **Restrict script permissions** so only the intended user can read it (`chmod 700 monitor_samba_speed.sh`).
> - **Never commit credentials** to version control — use environment variables or a secrets manager instead.

## License

MIT
