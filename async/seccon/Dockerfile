FROM golang:latest AS build
WORKDIR /src/
COPY . /src/
RUN CGO_ENABLED=0 go build -o /bin/seccon

FROM scratch
COPY --from=build /bin/seccon /bin/seccon
COPY console.html /
ENTRYPOINT ["/bin/seccon"]
