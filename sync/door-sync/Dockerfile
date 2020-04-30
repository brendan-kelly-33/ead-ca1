FROM golang:latest AS build
WORKDIR /src/
COPY . /src/
RUN CGO_ENABLED=0 go build -o /bin/door-sync

FROM scratch
COPY --from=build /bin/door-sync /bin/door-sync
ENTRYPOINT ["/bin/door-sync"]
