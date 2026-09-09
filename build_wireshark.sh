#!/bin/bash
#
# Make a set of dissectors and build custom wireshark build directory.
# To install the custom wireshark executables change directory to the build
# directory and use
#   sudo make install

ORIG_DIR=$(pwd)
WIRESHARK_LATEST_URL=https://1.na.dl.wireshark.org/src/wireshark-latest.tar.xz
WIRESHARK_SRC=$(realpath ./wireshark-src)
BUILD_DIR=$(pwd)/wireshark-build
OFILE_DIR="${WIRESHARK_SRC}/custom_epan"
CUSTOM_CMAKE_LIST_FILE=${WIRESHARK_SRC}/epan/dissectors/CMakeListsCustom.txt

eobi_proto_list=("14.0" "14.1" "15.0")
eti_proto_list=("14.0" "14.1" "15.0")

# dowload latest wireshark source and unpack to local source dir
curl -o /tmp/wireshark-latest.tar.xz "${WIRESHARK_LATEST_URL}"
mkdir -p "${WIRESHARK_SRC}"
tar xvf /tmp/wireshark-latest.tar.xz -C "${WIRESHARK_SRC}" --strip-components=1

# Can change this to only do this step if the build directory does not exist
mkdir -p "${BUILD_DIR}" && cd "${BUILD_DIR}" || exit
mkdir -p "${OFILE_DIR}"

SRC_LIST=""

# Process EOBI XML files
for p in "${eobi_proto_list[@]}"
do
    PROTO="eobi_$(echo "${p}" | tr "." "_")"
    PROTO_DIR="T7_$(echo "$PROTO" | tr [:lower:] [:upper:])"
    XML="${ORIG_DIR}/temp/${PROTO_DIR}/eobi.xml"
    OFILE="${OFILE_DIR}/packet-eobi-${p}.c"
    # echo "${p} => ${PROTO}, ${XML}, ${OFILE}"
    "${ORIG_DIR}"/eti2wireshark.py --proto "${PROTO}" --desc "Enhanced Order Book Interface" "${XML}" -o "${OFILE}"
    SRC_LIST="${SRC_LIST}\t${OFILE}\n"
done

# Process ETI XML files
for p in "${eti_proto_list[@]}"
do
    PROTO="eti_$(echo "${p}" | tr "." "_")"
    PROTO_DIR="T7_$(echo "$PROTO" | tr [:lower:] [:upper:])"
    XML="${ORIG_DIR}/temp/${PROTO_DIR}/eti_Derivatives.xml"
    OFILE="${OFILE_DIR}/packet-eti-${p}.c"
    # echo "${p} => ${PROTO}, ${XML}, ${OFILE}"
    "${ORIG_DIR}"/eti2wireshark.py --proto "${PROTO}" --desc "ETI Derivatives" "${XML}" -o "${OFILE}"
    SRC_LIST="${SRC_LIST}\t${OFILE}\n"
done

# Create custom dissector list for Cmake
cat > "${CUSTOM_CMAKE_LIST_FILE}"  << END
# CMakeListsCustom.txt
#
# Custom EOBI/ETI dissectors, generated using eti2wireshark.py

END

echo -e "set(CUSTOM_DISSECTOR_SRC\n$SRC_LIST)" >> "${CUSTOM_CMAKE_LIST_FILE}"

cmake "$WIRESHARK_SRC"

make -j32
cd "$ORIG_DIR" || exit
echo -e "To install Wireshark use:\ncd wireshark-build && sudo make install"