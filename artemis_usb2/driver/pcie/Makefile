
NAME=pcie_tester
SRC=src/main.cpp src/pcie_controller.cpp

CFLAGS=-Iinclude -Wall

BASE_DIR=${shell pwd}
BUILD_DIR=${BASE_DIR}/build


all: build

build: test

	g++ -o ${BUILD_DIR}/${NAME} ${CFLAGS} ${SRC}

test:

	@if [ ! -d "${BUILD_DIR}" ]; then 		\
		echo "Build directory not exists, creating build dir"; 	\
		mkdir -p ${BUILD_DIR}; 			\
	fi

clean:
	@echo "Removing build files"
	@rm -r ${BUILD_DIR}/
