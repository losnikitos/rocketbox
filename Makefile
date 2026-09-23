.PHONY: deploy restart tunnel

deploy:
	bin/kamal deploy

restart:
	touch tmp/restart.txt

# HTTPS to local Rails via kamal accessory (dev.rocketbox.plus → :3003)
tunnel:
	ssh -N -o ServerAliveInterval=30 -R 172.18.0.1:13003:127.0.0.1:3003 root@monitoring.tadaaa.uk.com
