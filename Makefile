.PHONY: deploy restart

deploy:
	bin/kamal deploy

restart:
	touch tmp/restart.txt
