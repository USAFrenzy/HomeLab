# Creating A User Login

- We're going to first create a user that essentially has root like capabilities to replace having to use the root token for logins. This will be our Administrator account.
- We can do this on the cli or in the Web UI, I've taken a liking to how streamlined the UI is, so this guide focuses on that aspect of Vault.

- Navigate over to Access -> Authentication Methods
  - Click on ```Enable new method +```
  - Click on ```Username & Password```
  - Change the path to whatever you'd like, although, it's fine to leave it as the default of ```userpass```
  - Next, click ```Enable Method```
<br>

- Navigate over to ```Policies``` and click on ```Create ACL policy +``` in the top right
- Create a new policy and name it something like ```Admin_Policy```
- In this ```Admin_Policy```, create your rules for this role. The below example gives full control over all paths under ```secrets```
```
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```
- If you need full root-like privileges for this admin account (strongly recommend *NOT* doing this, this should be limited to the root token that is securely stored away), then you can apply this to a wildcard root path like so:
```
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
```
<br>

- Now that the userpass engine has been enabled, Navigate back to ```Access``` -> ```Authentication``` Methods
  - Click on the userpass engine you just created
  - Click on ```Create user +```
  - Fill out the fields, use either the password or the password hash field
  - Expand the ```Tokens``` menu
  - Under ```Generated Token's Policies``` field, paste in the name of the policy you created for this user
  - Feel free to fine-tune the restrictions on the generated token for this user

- You can now sign in with this username and password. On the UI, you just have to swap the dropdown login method to select the userpass method


- You can create user accounts using this method with a multitude of control mechanisms, such as read-only accounts, or accounts limited to control over a specific aspect of management (like an account that can edit a very specific secrets engine and no others).