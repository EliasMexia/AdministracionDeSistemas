#!/bin/bash
clear
echo "Check status (Practica 1)"
echo ""
echo "NOMBRE DEL EQUIPO (HOSTNAME):"
hostname
echo ""
echo "DIRECCION IP ACTUAL:"
hostname -I
echo ""
echo "ESPACIO DISPONIBLE EN DISCO (Raiz):"
df -h | grep "/$"
echo ""