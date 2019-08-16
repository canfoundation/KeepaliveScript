#!/bin/bash
curl http://127.0.0.1:8888/v1/chain/get_info 2>&1
exit $?