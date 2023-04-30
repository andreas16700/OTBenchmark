
FROM swift:latest

WORKDIR /package

#Creates a cached layer for the dependencies
COPY Package.swift .
RUN swift package resolve

COPY . .
RUN swift package update

RUN swift build -c release
ENTRYPOINT [".build/release/otBench"]
