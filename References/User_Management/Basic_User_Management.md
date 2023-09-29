
# BASIC USER MANAGEMENT

<br>

### This file outlines creating new users on the Proxmox system, enabling that user as a system user, creating new groups, adding a user to a group, and setting up permissions for users and groups

<br>

_________________________

#### Part 1: Create The User On The Proxmox Host ####
_________________________


1) Navigate over to ```Datacenter```->```Permissions```->```Users```
2) Select ```Add```
3) Required Fields to fill out:
   - ```User name```
   - ```Realm``` - set to PAM or PVE depending on use case
     - PAM users are allowed more liberties on the system, such as ssh functions
     - PVE users are more restricted by default, for instance, they can't use ssh functions
   - ```Enabled``` - toggle to enable/disable user
4) Optional Fields to fill out:
   - ```Group``` - assign user to a group
   - ```Expire``` - set an expiry data
   - ```First Name```
   - ```Last Name```
   - ```E-Mail```
   - ```Key IDs``` - this field is used when adding a YubiKey

<br>

_________________________

#### NOTE: The Steps In Part 2 Need To Occur On Each Node That You Would Like The User To Have Access To
_________________________

<br>

_________________________

#### Part 2: Add The User To A Proxmox Node As A System User ####
_________________________

1) Select a node that you want to add the user to
2) Navigate over to ```>_ Shell```
3) Run ```adduser <user_name>```
4) Enter a password for the newly added user
5) Optional:
   - Fill out:
     - ```Full Name []:```
     - ```Room Number []:```
     - ```Work Phone []:```
     - ```Home Phone []:```
     - ```Other []:```
6) Verify that the information for this user is correct and hit ```enter``` or ```Y``` if correct

<br>

_________________________

#### NOTE: Part 3 Is Only Necessary To Add Permissions For The Group. Alternatively, This Can Be Omitted If The User Is Stand-Alone And Part 4 Is Followed For User Permission Instead ####
_________________________

<br>

_________________________

#### Part 3: Add The User To A Group ####
_________________________

1) If the user hasn't been assigned to a group and a group exists that the user should belong to:
   - Navigate back over to ```Datacenter```->```Permissions```->```Users```
   - Select the user
   - Click ```Edit```
   - Select ```Group```
   - Add the user to the group now
2) Otherwise, if no groups exist yet:
   - Navigate over to ```Datacenter```->```Permissions```->```Groups```
   - Select Create
   - Fill out the ```Name``` field
   - Navigate back over to ```Datacenter```->```Permissions```->```Users```
   - Select the user
   - Click ```Edit```
   - Select ```Group```
   - Add the user to the group now

<br>

_________________________

#### Part 4: Setting Permissions On The Group Or Stand-Alone User ####
_________________________

- If the user was added to a group that already existed and had permissions set, then the new user creation is complete!
- Otherwise, if the group that the user was added to had no permissions set yet or if the user is a stand-alone user, we now need to set up permissions:
1) Navigate over to ```Datacenter```->```Permissions```
2) Click ```Add v``` located at the top of the screen
3) Select either ```User Permission``` or ```Group Permission```
4) Under ```Path:```, select all permissions this group or user should have access to
5) Under ```Group:``` or ```User``` (depending on what permission type was selected), select the appropriate item to apply the access privileges to
6) Under ```Role:```, assign the role this user or group should have
7) Ensure the ```Propagate``` checkbox is ticked
8) Click ```Add```
