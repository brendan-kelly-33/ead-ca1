FROM golang:latest AS build
WORKDIR /src/
COPY . /src/
RUN CGO_ENABLED=0 go build -o /bin/door

FROM scratch
COPY --from=build /bin/door /bin/door
ENTRYPOINT ["/bin/door"]
