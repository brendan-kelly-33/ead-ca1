FROM golang:latest AS build
WORKDIR /src/
COPY . /src/
RUN CGO_ENABLED=0 go build -o /bin/seccon-sync

FROM scratch
COPY --from=build /bin/seccon-sync /bin/seccon-sync
COPY console.html /
ENTRYPOINT ["/bin/seccon-sync"]
