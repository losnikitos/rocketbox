.PHONY: deploy restart tunnel dev restore-prod-to-local

PROD_HOST := root@monitoring.tadaaa.uk.com
PROD_DB := /var/lib/docker/volumes/rocketbox_storage/_data/production.sqlite3

deploy:
	bin/kamal deploy

restart:
	touch tmp/restart.txt

# HTTPS to local Rails via kamal accessory (dev.rocketbox.plus → :3003)
tunnel:
	ssh -N -o ServerAliveInterval=30 -R 172.18.0.1:13003:127.0.0.1:3003 root@monitoring.tadaaa.uk.com

dev:
	bin/dev

# Replace storage/development.sqlite3 with a snapshot of prod (queue db untouched).
restore-prod-to-local:
	@set -e; \
	mkdir -p tmp/db_backups; \
	LOCAL_PATH="tmp/db_backups/production_$$(date +%Y%m%d%H%M%S).sqlite3"; \
	echo "Snapshotting prod db..."; \
	ssh $(PROD_HOST) "sqlite3 $(PROD_DB) '.backup /tmp/rocketbox_pull.sqlite3' && cat /tmp/rocketbox_pull.sqlite3 && rm /tmp/rocketbox_pull.sqlite3" > $$LOCAL_PATH; \
	echo "Restoring into storage/development.sqlite3..."; \
	rm -f storage/development.sqlite3-wal storage/development.sqlite3-shm; \
	cp $$LOCAL_PATH storage/development.sqlite3; \
	bin/rails db:environment:set RAILS_ENV=development; \
	bin/rails db:migrate
