@echo off
chcp 65001
set PGCLIENTENCODING=UTF8
REM ⥪�騩 ���� ����᪠ cmd 䠩��
SET PATH_CURRENT=%~dp0
CD "%PATH_CURRENT%"
REM ���������� �६� ���� ���������� (��� ����⨪�)
SET UPGSTART=%TIME%
REM ��� � �� � ����୨���
SET PGDATA_OLD=D:\PostgresData_9.4
SET PGDATA_NEW=D:\PostgresData_9.5
SET PGBIN_OLD=C:\Program Files\PostgreSQL\9.4\bin
SET PGBIN_NEW=C:\Program Files\PostgresPro\9.5\bin
REM ��ࠬ���� ��� ���樠����樨 ������ ��
SET PGLOCALE=English, United States
SET PGENCODING=UTF8
REM ᪮�쪮 ��殢 �ᯮ�짮���� ��� ����������
SET PGCORE=8
REM ᪮�쪮 ��殢 �ᯮ�짮���� ��� ᡮ� ����⨪�
SET PGCOREV=4
D:
SET PATH=%PATH%;%PGBIN_NEW%;

REM ��⠭�������� 9.5
net stop postgresql-x64-9.5
if %ERRORLEVEL% == 0 goto initdb
if %ERRORLEVEL% == 2 goto initdb
echo ===========================================
echo Service "postgresql-x64-9.5" failed to stop
echo ===========================================
goto endscript

:initdb
REM ᮧ���� ������ ������ � �㦭묨 ��� ����ன����
REM �����⠢������ ����� ��� ����⠭������� ��娢�. ����塞 ���
copy /Y "%PGDATA_NEW%\postgresql.conf" "%PATH_CURRENT%\postgresql.conf"
rd /S /Q "%PGDATA_NEW%\base"
rd /S /Q "%PGDATA_NEW%\global"
rd /S /Q "%PGDATA_NEW%\pg_clog"
rd /S /Q "%PGDATA_NEW%\pg_dynshmem"
rd /S /Q "%PGDATA_NEW%\pg_log"
rd /S /Q "%PGDATA_NEW%\pg_logical"
rd /S /Q "%PGDATA_NEW%\pg_multixact"
rd /S /Q "%PGDATA_NEW%\pg_notify"
rd /S /Q "%PGDATA_NEW%\pg_replslot"
rd /S /Q "%PGDATA_NEW%\pg_serial"
rd /S /Q "%PGDATA_NEW%\pg_snapshots"
rd /S /Q "%PGDATA_NEW%\pg_stat"
rd /S /Q "%PGDATA_NEW%\pg_stat_tmp"
rd /S /Q "%PGDATA_NEW%\pg_subtrans"
rd /S /Q "%PGDATA_NEW%\pg_tblspc"
rd /S /Q "%PGDATA_NEW%\pg_twophase"
rd /S /Q "%PGDATA_NEW%\pg_xlog"
rd /S /Q "%PGDATA_NEW%\pg_commit_ts"
del /Q "%PGDATA_NEW%\*.*"
REM ��⠭�������� � �㦭�� �������
"%PGBIN_NEW%\initdb.exe" -U postgres -D %PGDATA_NEW% -E %PGENCODING% --locale="%PGLOCALE%"
if %ERRORLEVEL% == 0 goto prepare1
echo ===========================================
echo Init cluster postgresql 9.5 failed
echo ===========================================
goto endscript


:prepare1
REM ����⠭�������� ��室�� 䠩� ����஥� � �㦭� ���⮬
copy /Y "%PATH_CURRENT%\postgresql.conf" "%PGDATA_NEW%\postgresql.conf" 
if %ERRORLEVEL% == 0 goto prepare2
echo ===========================================
echo copy postgresql.conf failed
echo ===========================================
goto endscript

:prepare2
REM �����㥬 �㤠 pg_hba.conf
copy /Y %PGDATA_OLD%\pg_hba.conf %PGDATA_NEW%\pg_hba.conf
if %ERRORLEVEL% == 0 goto prepare3
echo ===========================================
echo copy pg_hba.conf failed
echo ===========================================
goto endscript

:prepare3
REM �����㥬 �㤠 pg_ident.conf
copy /Y %PGDATA_OLD%\pg_ident.conf %PGDATA_NEW%\pg_ident.conf
if %ERRORLEVEL% == 0 goto prepare4
echo ===========================================
echo copy pg_ident.conf failed
echo ===========================================
goto endscript

:prepare4
REM ᮧ��� 䠩� �⥭�� ����⨪� �� �ᥬ ��
"%PGBIN_OLD%\psql.exe" -h localhost -U "postgres" -t -A -o upgrade_dump_stat_old.sql -c "select '\c ' || datname || E'\nCREATE EXTENSION IF NOT EXISTS dump_stat;\n\\o dump_stat_' || datname || E'.sql\n' || E'select dump_statistic();\n' from pg_database where datistemplate = false and datname <> 'postgres';"
REM ᮧ��� 䠩� �������� ����⨪� �� ���� �ࢥ�...
"%PGBIN_OLD%\psql.exe" -h localhost -U "postgres" -t -A -o upgrade_dump_stat_new.sql -c "select '\c ' || datname || E'\nCREATE EXTENSION IF NOT EXISTS dump_stat;\n\\i dump_stat_' || datname || E'.sql\n' from pg_database where datistemplate = false and datname <> 'postgres';"
REM �믮��塞 ��ନ஢���� 䠩� - upgrade_dump_stat_old.sql
"%PGBIN_OLD%\psql.exe" -h localhost -U "postgres" -t -A -f "upgrade_dump_stat_old.sql"

REM �����㥬 �㤠 ����� ����� postgresql.conf
copy /Y %PGDATA_OLD%\postgresql_new.conf %PGDATA_NEW%\postgresql.conf
if %ERRORLEVEL% == 0 goto stop_9_4
echo ===========================================
echo copy postgresql.conf failed
echo ===========================================
goto endscript

:stop_9_4
net stop postgresql-x64-9.4
if %ERRORLEVEL% == 0 goto check
if %ERRORLEVEL% == 2 goto check
echo ===========================================
echo Service "postgresql-x64-9.4" failed to stop
echo ===========================================
goto endscript

:check
REM �஢�ઠ ��। �����������...
echo ==========================================================================================
echo =========                                                                   ==============
echo =========                                                                   ==============
echo =========                         UPGRADE CHECK                             ==============
echo =========                                                                   ==============
echo =========                                                                   ==============
echo ==========================================================================================
"%PGBIN_NEW%\pg_upgrade.exe" --old-datadir "%PGDATA_OLD%" --new-datadir "%PGDATA_NEW%" --old-bindir "%PGBIN_OLD%" --new-bindir "%PGBIN_NEW%" --old-port 5432 --new-port 5433 --verbose --username postgres --check
if %ERRORLEVEL% == 0 goto upgrade_cluster
echo ===========================================
echo pg_upgrade check failed
echo ===========================================
goto endscript

:upgrade_cluster
REM ᠬ �����... ( --jobs 8 -> ����� �� 8 ���)
echo ==========================================================================================
echo =========                                                                   ==============
echo =========                                                                   ==============
echo =========                        UPGRADE START!!!                           ==============
echo =========                                                                   ==============
echo =========                                                                   ==============
echo ==========================================================================================
"%PGBIN_NEW%\pg_upgrade.exe" --old-datadir "%PGDATA_OLD%" --new-datadir "%PGDATA_NEW%" --old-bindir "%PGBIN_OLD%" --new-bindir "%PGBIN_NEW%" --old-port 5432 --new-port 5433 --verbose --username postgres --link --retain --jobs %PGCORE%
if %ERRORLEVEL% == 0 goto start_9_5
echo ===========================================
echo pg_upgrade cluster failed
echo ===========================================
goto endscript

:start_9_5
REM ����᪠�� �ࢨ�
net start postgresql-x64-9.5
if %ERRORLEVEL% == 0 goto endprocess
echo ===========================================
echo Service "postgresql-x64-9.5" failed to start
echo ===========================================
goto endscript

:endprocess
echo ==========================================================================================
echo =========                                                                   ==============
echo =========                         UPGRADE END                               ==============
echo =========                                                                   ==============
echo ==========================================================================================
REM ����ᨬ ����⨪� �� ���� �ࢥ� - upgrade_dump_stat_new.sql
"%PGBIN_NEW%\psql.exe" -h localhost -U "postgres" -t -A -f "upgrade_dump_stat_new.sql"
echo ==========================================================================================
echo =========                                                                   ==============
echo Start process at %UPGSTART%
echo End process at %TIME%
echo =========                                                                   ==============
echo ==========================================================================================
echo ==========================================================================================
echo =========                      job_prewarm                                  ==============
REM ������塞 ��� ������ �㦭묨 ��ꥪ⠬�
"%PGBIN_NEW%\psql.exe" -h localhost -U "postgres" -d sparkmes -c "select public.job_prewarm();"
echo =========                                                                   ==============
echo ==========================================================================================
REM ����᪠�� ���������� ����⨪�
"%PGBIN_NEW%\vacuumdb.exe" -U postgres -p 5432 -j %PGCOREV% --all --analyze-in-stages
:endscript
pause
