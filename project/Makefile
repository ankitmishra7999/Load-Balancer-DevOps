.PHONY: all

all:
    
	docker build -t ds_server:latest ./server --platform linux/x86_64
	docker compose up -d

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