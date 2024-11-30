#!/bin/bash

# Dependencies:
# - cmake
# - curl
# - g++
# NOTE: Dependencies should be installed outside the script to allow the script to be largely distro-agnostic

# Exit on any error
set -e

cUsage="Usage: ${BASH_SOURCE[0]} <version>[ <.deb output directory>]"
if [ "$#" -lt 1 ] ; then
    echo $cUsage
    exit
fi
version=$1

package_name=fmtlib
temp_dir=/tmp/${package_name}-installation
deb_output_dir=${temp_dir}
if [[ "$#" -gt 1 ]] ; then
  deb_output_dir="$(readlink -f "$2")"
  if [ ! -d ${deb_output_dir} ] ; then
    echo "${deb_output_dir} does not exist or is not a directory"
    exit
  fi
fi

# Check if already installed
set +e
dpkg -l ${package_name} | grep ${version}
installed=$?
set -e
if [ $installed -eq 0 ] ; then
  # Nothing to do
  exit
fi

echo "Checking for elevated privileges..."
privileged_command_prefix=""
if [ ${EUID:-$(id -u)} -ne 0 ] ; then
  sudo echo "Script can elevate privileges."
  privileged_command_prefix="${privileged_command_prefix} sudo"
fi

# Get number of cpu cores
num_cpus=$(grep -c ^processor /proc/cpuinfo)

# Download
mkdir -p $temp_dir
cd $temp_dir
extracted_dir=${temp_dir}/fmt-${version}
if [ ! -e ${extracted_dir} ] ; then
  tar_filename=${version}.tar.gz
  if [ ! -e ${tar_filename} ] ; then
    curl -fsSL https://github.com/fmtlib/fmt/archive/refs/tags/${tar_filename} -o ${tar_filename}
  fi

  tar -xf ${tar_filename}
fi

# Build
cd ${extracted_dir}
mkdir -p cmake-build-release
cd cmake-build-release
cmake -DCMAKE_POSITION_INDEPENDENT_CODE=ON ../
make -j${num_cpus}

# Check if checkinstall is installed
set +e
command -v checkinstall
checkinstall_installed=$?
set -e

# Install
install_command_prefix="${privileged_command_prefix}"
if [ $checkinstall_installed -eq 0 ] ; then
  install_command_prefix="${install_command_prefix} checkinstall --pkgname '${package_name}' --pkgversion '${version}' --provides '${package_name}' --nodoc -y --pakdir \"${deb_output_dir}\""
fi
${install_command_prefix} make install

# Clean up
rm -rf $temp_dir