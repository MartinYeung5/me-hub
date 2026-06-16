#!/usr/bin/env bash
SWAGGER_DIR=./swagger-proto

set -eo pipefail

if [ ! -d "$SWAGGER_DIR/proto" ]; then
  mkdir -p $SWAGGER_DIR/proto
fi

printf "version: v1\ndirectories:\n  - proto\n  - third_party" > "$SWAGGER_DIR/buf.work.yaml"
printf "version: v1\nname: buf.build/dymensionxyz/dymension\n" > "$SWAGGER_DIR/proto/buf.yaml"
cp ./proto/buf.gen.swagger.yaml "$SWAGGER_DIR/proto/buf.gen.swagger.yaml"

# copy existing proto files
cp -r ./proto/metaearth "$SWAGGER_DIR/proto"

if [ ! -d "./tmp-swagger-gen" ]; then
  mkdir -p ./tmp-swagger-gen
fi

# step into swagger folder
cd "$SWAGGER_DIR"

# create swagger files on an individual basis  w/ `buf build` and `buf generate` (needed for `swagger-combine`)
proto_dirs=$(find ./proto ./third_party -path -prune -o -name '*.proto' -print0 | xargs -0 -n1 dirname | sort | uniq)
# echo "${proto_dirs[@]}"
for dir in $proto_dirs; do
  # generate swagger files (filter query files)
  query_file=$(find "${dir}" -maxdepth 1 \( -name 'query.proto' -o -name 'service.proto' \))
  if [[ -n "$query_file" ]]; then
    buf generate --template proto/buf.gen.swagger.yaml --path "$query_file"
  fi
done

cd ..

# combine swagger files
# uses nodejs package `swagger-combine`.
# all the individual swagger files need to be configured in `config.json` for merging
# Verify that the config file exists before combining
if [ ! -f "./docs/config.json" ]; then
    echo "ERROR: config.json not found at ./docs/config.json" >&2
    exit 1
fi

# Ensure output directory exists
if [ ! -d "./docs/static" ]; then
    echo "INFO: Creating output directory ./docs/static"
    mkdir -p "./docs/static"
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create ./docs/static" >&2
        exit 1
    fi
fi

# Execute swagger-combine with proper error handling
if ! swagger-combine ./docs/config.json -o ./docs/static/openapi.yml -f yaml --continueOnConflictingPaths true --includeDefinitions true; then
    echo "ERROR: swagger-combine failed. Check config.json and input files." >&2
    exit 1
fi

# clean swagger files
#rm -rf ./tmp-swagger-gen
#rm -rf "$SWAGGER_DIR"
