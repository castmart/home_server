# Syncthing — First Run

Do this procedure one time, on a server that has no Syncthing data yet. Do the
steps in order. Later starts need no preparation.

This procedure is written in ASD-STE100 Simplified Technical English: one
instruction per sentence, the imperative, and one meaning for each word.

For what the settings mean and how to operate Syncthing after the first run,
read the Syncthing section of [README.md](README.md).

---

**CAUTION: Do not start the stack before step 3. The compose file stops all the
services, Immich included, if the two Syncthing variables are not in the `.env`
file.**

## Part 1 — Prepare the server

1. Open a terminal on the server.

2. Go to the project directory.

3. Add the three variables to the `.env` file.

   ```bash
   printf '\nSYNCTHING_GUI_USER=admin\nSYNCTHING_GUI_PASSWORD=change-me\nOBSIDIAN_PATH=/mnt/data/syncthing/obsidian\n' >> .env
   ```

4. Replace `change-me` with a strong password.

5. Make the two directories. Give them to the user 1000.

   ```bash
   sudo install -d -o 1000 -g 1000 /mnt/data/syncthing/obsidian ./syncthing/config
   ```

   The container entrypoint changes the owner of `/var/syncthing` only. It does
   not change the owner of the directories below it. A directory that belongs to
   root stops Syncthing from writing to it.

6. Show the owner of the new directories.

   ```bash
   ls -ld /mnt /mnt/data /mnt/data/syncthing /mnt/data/syncthing/obsidian ./syncthing/config
   ```

7. Make sure that the output is correct:

   | Directory | Correct owner |
   |-----------|---------------|
   | `./syncthing/config` | your user, which is the user 1000 |
   | `/mnt/data/syncthing/obsidian` | your user, which is the user 1000 |
   | `/mnt`, `/mnt/data`, `/mnt/data/syncthing` | `root`, with the mode `755` |

   The parent directories that belong to root are correct. The mode `755` lets
   the user 1000 go through them. Syncthing writes in `obsidian` only. Do not
   change the owner of the parent directories.

   If `ls` shows your user name for a directory that you made with `-o 1000`,
   then your user is the user 1000. This is what the `PUID` and `PGID` settings
   in the compose file need.

8. Make the vault private to your user. This step is optional.

   ```bash
   chmod 750 /mnt/data/syncthing/obsidian
   ```

## Part 2 — Start Syncthing

9. Start the two containers.

   ```bash
   docker compose up -d syncthing
   ```

10. Read the log of the bootstrap container.

    ```bash
    docker compose logs syncthing_init
    ```

11. Make sure that the log shows no errors.

12. Show the status of the bootstrap container.

    ```bash
    docker compose ps -a syncthing_init
    ```

13. Make sure that the status is `Exited (0)`. This status is correct. The
    container does its task one time, then it stops.

14. Open `http://<server-address>:8384` in a browser.

15. Type the user name and the password from step 3.

16. Remove the default folder if the interface shows one. This folder has no
    volume on the host. Its contents do not survive a restart.

## Part 3 — Check the device identity

The device ID comes from the certificate in `./syncthing/config`. A new device
ID disconnects all the paired devices. These steps make sure that the ID stays
the same after each start.

17. Click **Actions**, then click **Show ID**.

18. Write the device ID in a safe place.

19. Start the containers again.

    ```bash
    docker compose up -d syncthing
    ```

20. Show the device ID again. Make sure that the device ID is the same.

**CAUTION: Do not continue if the device ID is different. Stop, and find the
cause first.**

21. Show the version of Syncthing.

    ```bash
    docker compose exec syncthing syncthing --version
    ```

22. Add that version to the `.env` file as `SYNCTHING_VERSION`. This stops an
    unwanted upgrade.

## Part 4 — Connect the first device

In this part the laptop has the vault and the server is empty. The server must
receive the files. It must not send its empty directory.

23. Install Syncthing on the laptop.

24. On the laptop, add the vault folder.

25. On the laptop, add the ignore patterns to that folder. Do this step before
    step 27.

    ```
    .obsidian/workspace.json
    .obsidian/workspace-mobile.json
    .obsidian/cache
    .trash
    .DS_Store
    ```

    These files change very often, or they apply to one machine only. They make
    conflict copies if you sync them.

26. On the laptop, add the server as a remote device. Use the device ID from
    step 18.

27. On the server, accept the new device.

28. On the laptop, share the folder with the server.

29. On the server, accept the folder. Set the folder path to
    `/var/syncthing/obsidian`.

30. On the server, set the folder type to **Receive Only**.

**CAUTION: Obey step 30. The server directory is empty. An empty directory can
delete the files on the laptop if the two folder types are Send & Receive.**

31. Wait until the server shows **Up to Date**.

32. Make sure that the files are in the server directory.

    ```bash
    ls -la /mnt/data/syncthing/obsidian
    ```

33. On the server, set the folder type to **Send & Receive**.

34. On the server, set **File Versioning** to Simple for that folder. Syncthing
    renames one side of a true conflict to `*.sync-conflict-*`. File versioning
    lets you get the other side back.

## After the first run

- The `.env` file holds the password. Each `docker compose up -d` writes the
  password again. A password that you change in the web interface goes back to
  the value in `.env` at the next start. Change the password in `.env`.
- Syncthing finds devices on the local network with a broadcast on port 21027.
  A broadcast does not go across networks. To sync over Tailscale, read the
  Syncthing section of [README.md](README.md).
