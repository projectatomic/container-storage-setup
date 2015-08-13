#!/bin/bash
# Library for common functions

check_data_size_syntax() {
  local data_size=$1

  # if it is all numeric, it is valid as by default it will be MB.
  [[ $data_size =~ ^[[:digit:]]+$ ]] && return 0

  # -L compatible syntax
  if [[ $data_size != *%* ]]; then
    # Numeric digits followed by valid suffix.
    [[ $data_size =~ ^[[:digit:]]+[bBsSkKmMgGtTpPeE]$ ]] && return 0
  fi

  # For -l style options, we only support %FREE and %VG option. %PVS and
  # %ORIGIN does not seem to make much sense for this use case.
  if [[ $data_size == *%FREE ]] || [[ $data_size == *%VG ]];then
    return 0
  fi

  return 1
}

check_min_data_size_syntax() {
  local min_data_size=$1

  # if it is all numeric, it is valid as by default it will be MB.
  [[ $min_data_size =~ ^[[:digit:]]+$ ]] && return 0

  # Numberic digits followed by valid suffix.
  [[ $min_data_size =~ ^[[:digit:]]+[bBsSkKmMgGtTpPeE]$ ]] && return 0

  return 1
}
