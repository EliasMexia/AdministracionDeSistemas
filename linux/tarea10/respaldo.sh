#!/bin/bash
FECHA=$(date +%Y%m%d_%H%M%S)
docker exec db_server pg_dump -U admin appdb > /home/tu_usuario/respaldo_$FECHA.sql
