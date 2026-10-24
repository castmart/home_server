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

24. On the laptop, open `http://127.0.0.1:8384`.

**CAUTION: The two interfaces use the same port, 8384. The laptop uses the
address `127.0.0.1`. The server uses its own network address. Read the device
name at the top of the page before each step.**

25. On the laptop, add the vault folder.

26. On the laptop, add the ignore patterns to that folder. Do this step before
    step 30.

    ```
    .obsidian/workspace.json
    .obsidian/workspace-mobile.json
    .obsidian/cache
    .trash
    .DS_Store
    ```

    These files change very often, or they apply to one machine only. They make
    conflict copies if you sync them.

27. On the laptop, click **Add Remote Device**.

    If the laptop and the server are on the same local network, the server shows
    in the **Nearby Devices** list. Click the server to fill in the device ID.
    If the list is empty, type the device ID from step 18.

    To connect over Tailscale, click **Advanced**. In the **Addresses** field,
    replace `dynamic` with `tcp://<machine>.<tailnet>.ts.net:22000`. A local
    network finds devices with a broadcast, and a broadcast does not go across
    networks.

28. On the server, accept the new device.

29. On the laptop, make sure that the server shows **Connected (Unused)**.

    This status is correct at this point. The two devices talk to each other,
    but they share no folder yet. The folder shows **Unshared** for the same
    reason.

30. On the laptop, click the folder. Click **Edit**, then click **Sharing**.
    Select the server, then click **Save**.

31. On the server, a message asks you to add the folder. Set the folder path to
    `/var/syncthing/obsidian`.

**CAUTION: Use the path inside the container, `/var/syncthing/obsidian`. Do not
use the path on the host, `/mnt/data/syncthing/obsidian`. Syncthing runs in the
container and sees only the container path. The host path makes a directory in
the container that a restart removes.**

32. In the same dialog, click **Advanced**. Set the folder type to **Receive
    Only**. Then click **Save**.

**CAUTION: Obey step 32 before you save. The server directory is empty. An empty
directory can delete the files on the laptop if the two folder types are Send &
Receive.**

33. Wait until the server shows **Up to Date**.

34. Make sure that the files are in the server directory.

    ```bash
    ls -la /mnt/data/syncthing/obsidian
    ```

35. On the server, set the folder type to **Send & Receive**.

36. On the server, set **File Versioning** to Simple for that folder. Syncthing
    renames one side of a true conflict to `*.sync-conflict-*`. File versioning
    lets you get the other side back.

## Part 5 — Add a phone

Do this part after Part 4. The server now holds the vault, and the phone is
empty.

**CAUTION: The official Syncthing application for Android was discontinued in
2024. Google Play removed the official application and the community fork,
because Syncthing needs the "all files access" permission. Do not look for them
in Google Play.**

37. For Android, install **Syncthing-Fork** from F-Droid, or from its releases
    page on GitHub. It is the maintained community application.

38. For iOS, know that Syncthing has no official application. Third-party
    applications exist. Check that one is maintained before you trust your notes
    to it.

39. On the phone, add the server as a remote device. Use the device ID from
    step 18.

40. On the server, accept the new device.

41. On the server, click the folder. Click **Edit**, then click **Sharing**.
    Select the phone, then click **Save**.

42. On the phone, accept the folder. Set the folder type to **Receive Only**
    before you save it.

43. Wait until the phone shows **Up to Date**.

44. On the phone, set the folder type to **Send & Receive**. Do this step only
    if you want to change the notes on the phone. A Receive Only folder cannot
    send your changes back.

45. On Android, remove the battery optimization for the application. Android
    stops a background application that it optimizes, and the sync stops too.

## After the first run

- The `.env` file holds the password. Each `docker compose up -d` writes the
  password again. A password that you change in the web interface goes back to
  the value in `.env` at the next start. Change the password in `.env`.
- Syncthing finds devices on the local network with a broadcast on port 21027.
  A broadcast does not go across networks. To sync over Tailscale, read the
  Syncthing section of [README.md](README.md).
