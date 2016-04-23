
NAME=pcie_tester
PWD=${shell pwd}
SRCDIR=${PWD}/src
SRC=${SRCDIR}/main.cpp ${SRCDIR}/pcie_controller.cpp

CFLAGS=-Iinclude -Wall

BUILD_DIR=${PWD}/build


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
	@rm -r ${BUILD_DIR}
