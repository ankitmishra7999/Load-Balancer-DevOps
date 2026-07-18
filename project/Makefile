.PHONY: all

all:

	docker build -t ds_server:latest ./server --platform linux/x86_64
	# --build: `docker compose up -d` alone only builds an image if one
	# with that name doesn't already exist yet - it does NOT notice that
	# the Dockerfile/source changed and silently reuses a stale image
	# otherwise. --build forces it to actually rebuild every time.
	docker compose up -d --build

clean:
	docker compose down --rmi all
	@containers=$$(docker ps -a -q); \
	if [ -n "$$containers" ]; then \
		docker stop $$containers; \
		docker rm $$containers; \
	fi
	-docker network rm pub
	-docker image rm ds_server:latest

restart:
	make clean ; make all