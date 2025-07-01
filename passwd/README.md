# This folder is used by the root `Makefile` as a mount volume where passwd files for basic & digest auth are to be placed

## To generate a basic auth file:
- `htpasswd -c basic.passwd <user>`

## To generate a digest auth file:
- `htdigest -c digest.passwd harness <user>`

