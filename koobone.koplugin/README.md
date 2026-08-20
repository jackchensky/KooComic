# KOOBONE for KOReader — experimental v0.1

This is a first experimental plugin built from the KOOBONE web requests observed in Chrome DevTools.

## What it does

- Log in to your own KOOBONE account.
- Stores session cookies only (not your password).
- Reads your KOOBONE library from `vol_list.php`.
- Shows each volume with title, author, size and last-read page.
- Downloads the EPUB directly from the signed `file_url`.
- Saves downloads into a `KOOBONE` folder under your KOReader home/library folder.
- Opens the downloaded EPUB in KOReader.

## Install

Copy the entire folder:

`koobone.koplugin`

to:

`koreader/plugins/`

Then fully restart KOReader.

Open:

Tools → KOOBONE

## Important

This is an experimental first version. KOOBONE is not a documented public API, so the website can change at any time.

If login fails, do not repeatedly submit your password. Capture `crash.log` / KOReader logs and inspect the endpoint behaviour first.

The plugin never needs your KBSKEY/VLIBSID pasted manually. Do not share session cookie values.
