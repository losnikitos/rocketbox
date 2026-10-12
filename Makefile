.PHONY: deploy restart tunnel dev stop restore-prod-to-local

PROD_HOST := root@monitoring.tadaaa.uk.com
PROD_DB := /var/lib/docker/volumes/rocketbox_storage/_data/production.sqlite3

deploy:
	bin/kamal deploy

restart:
	touch tmp/restart.txt

# HTTPS to local Rails via kamal accessory (dev.rocketbox.plus → :3003).
# The server keeps a dead session's :13003 for ~90s, so free it before each try; retry every 2s.
tunnel:
	while :; do \
		ssh -o ConnectTimeout=10 $(PROD_HOST) 'fuser -k 13003/tcp' >/dev/null 2>&1; \
		ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=2 -o ConnectTimeout=10 \
			-R 172.18.0.1:13003:127.0.0.1:3003 $(PROD_HOST); \
		sleep 2; \
	done

dev:
	bin/dev

# Stop a running bin/dev (from any terminal) and anything still holding :3003.
stop:
	@old=$$(cat tmp/pids/dev.pid 2>/dev/null); \
	if [ -n "$$old" ] && ps -p "$$old" -o command= | grep -q foreman && kill "$$old"; then \
		while kill -0 "$$old" 2>/dev/null; do sleep 0.2; done; \
	fi; \
	lsof -ti tcp:3003 -sTCP:LISTEN | xargs kill -9 2>/dev/null; \
	rm -f tmp/pids/dev.pid

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
	bin/rails db:migrate data:migrate
