 # Setting Up System Alerts And Configuring Email Relay

<br>

_________________________

### Configuring Email Relay Service

_________________________
-  Run "```apt update```" to ensure everything is up-to-date first
- Now to install the dependencies:
  -  Run "```apt install -y libsasl2-modules mailutils```" (used to securely connect to SMTP server)
  -  Install one last dependency by running "```apt install postfix-pcre```"
  -  Choose an email address for logging (mine is using the rc-server domain's gmail address)
    - If using Gmail, sign into your email account that will be used for sending logging info
    - Go Under ```Manage Your Account```->```Settings```->```Security```->```Google Sign In```->```App Passwords```
    - Create an app password for the type ```Mail``` and under ```Device```, select ```Other``` and name it
    - Click ```Generate``` and copy the token someplace safe and secure
  -  Navigate back over to the Proxmox shell
  -  Run ```echo "smtp.gmail.com <your_email_address>@gmail.com:<your_app_password>" > /etc/postfix/sasl_passwd```
    - This is the location that the ```postfix``` service will use to read for the credentials
  - Now we encode it by hashing the file with ```postmap``` by running "```postmap hash:/etc/postfix/sasl_passwd```"
  - For security reasons, change the permissions to owner=rw, group=none, other=none by running ```chmod 600 /etc/postfix/sasl_passwd```
    - Read=4, write=2, execute=1 -> each digit is the sum of these permissions for the owner, group, and others respectively
    - Example: if everyone had full permissions, they would each have read, write, & execute which adds up to 7 ==> the permission level would be 777
  -  Create header check file by running "```nano /etc/postfix/smtp_header_checks```" (This is used to change the name of the user in the email from root)
     -  Add ```/^From:.*/ REPLACE From: pve1-alert <pve1-alert@something.com>``` to the file
     - Just like with the postfix passwd file, we need to hash this file as well:
       - Run "```postmap hash:/etc/postfix/smtp_header_checks```"
  -  Now to configure postfix:
    -  Run "```nano /etc/postfix/main.cf```
    -  Under the ```compatibility_level``` field, paste in:
       - ```relayhost = smtp.gmail.com:587```
       - ```smtp_use_tls = yes```
       - ```smtp_sasl_auth_enable = yes```
       - ```smtp_sasl_security_options =```
       - ```smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd```
       - ```smtp_tls_CAfile = /etc/ssl/certs/Entrust_Root_Certification_Authority.pem```
       - ```smtp_tls_session_cache_database = btree:/var/lib/postfix/smtp_tls_session_cache```
       - ```smtp_tls_session_cache_timeout = 3600s```
       - ```smtp_header_checks = pcre:/etc/postfix/smtp_header_checks```
     - Run "```postfix reload```" to reload the new config settings in
     - To test the connection, send a test email:
       - Run "```echo "<your_test_message>" | mail -s "<your_email_header>" <your_email_address>```"

<br>

_________________________

### Mapping the email used in the email relay to a user

_________________________
- Navigate over to ```Datacenter```->```Users```
  - Select a user and click ```Edit```
  - In the ```Email``` field, add the email used when setting up the email relay

<br>

_________________________

### Checking that disks have S.M.A.R.T Alerts Enabled

_________________________
- For Each Disk, Run "```smartctl -a /dev/<disk>```
- Check That The Field: ```SMART support is:``` states ```Available - device has SMART capability```.
- Check That The Field: ```SMART support is:``` states ```Enabled```

<br>


_________________________

### Setting Up ZFS Alerts

_________________________
- Run "```nano /etc/zfs/zed.d/zed.rc```"
- Locate The Line: ```ZED_EMAIL_ADDR``` and ensure it reads as ```ZED_EMAIL_ADDR="root"``` and is not commented out


<br>

_________________________

### Setting Up Backup Alerts

_________________________
- Navigate over to ```Datacenter```->```Backup```
  - If a backup task has already been created, then highlight it, click ```Edit```
  - In the ```Send email to``` field, add the email address used when setting up the email relay service

<br>