@echo off
REM 
REM ���������� � ���ᨨ 9.4 �� ���ᨨ 9.5 
REM ��⠭�������� ����� ����� �ࢥ� �� ���� 5433 � ���� DATA ��⠫�� D:/PostgresData_9.5
REM �� ���� ������...
REM 
SET PATH_CURRENT=%~dp0
RUNAS /USER:postgres "%PATH_CURRENT%upgrade_cluster_process.cmd"



