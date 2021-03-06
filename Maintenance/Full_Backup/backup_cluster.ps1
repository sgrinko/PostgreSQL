﻿##############################################################################
#
# Версия - 1.0
#
##############################################################################
# 
# Выполняет архивирование кластера БД
# имя архива кластера будет: postgres_YYYY_MM_DD_cluster.backup.7z
# Архив сохраняется по пути: PGARCHIVE и PGARCHIVE_NET
#  ________________________________________________________________________________
# | Дата изменения |   Кто изменял    | Версия скрипта | Причины изменения
# |________________________________________________________________________________
# |   11.09.2015   |  Гринько Сегей   |     1.0        | Создание данного скрипта
# |________________________________________________________________________________
#
# использование:
# powershell.exe <полное имя файла скрипта>
#
##############################################################################

# контроль за неопределёнными переменными, ссылок на несуществующие свойства, 
# неименованные переменные типа ${}, вызовы функций и методов .NET
Set-strictMode -Version "2.0"
cls

#Время начала скрипта
$ScriptStartDate = date
	
    #################################
    ###     ВХОДНЫЕ ПАРАМЕТРЫ     ###
    #################################
	
# различные пути обработки, хранения бэкапа и служебных программ

# рабочий каталог кластера
$PgData = 'D:\PostgreSQL_DATA_9.4'
# каталог создания копии кластера
$PgArchive = 'D:\Backup\PostgreSQL\BAK'
# сетевой каталог хранения бэкапа
$PgArchiveNet = '\\my_backup\PostgreSQL\MYDB'
# сетевой каталог хранения копий WAL файлов
$PgArchiveWal = '\\my_backup\PostgreSQL\WAL'

# программа создания копии кластера
$PgBasebackupFullName = 'C:\Program Files\PostgreSQL\9.4\bin\pg_basebackup.exe'
# программа архивации
$ArcProgram = 'C:\Program Files\7-Zip\7z.exe'
# расширение файла архива
$ArcProgramExt = '7z'
$ArcProgramParam = 'a -r -mx=3 -sdel'

#Описание сервера Postrges для использования в письмах
$PostrgesDescription = 'MYDB01'

#Тема сообщения об ошибке
$MailSubject = "Создание полного бэкапа $PostrgesDescription"
 
#Параметры почтового сервера
$MailFrom = 'MYDB@email.ru'

#Сколько дней храним бэкапы
$RetentionDays = 21

# имя триггер файла, маркера бэкапирования WAL логов
$FileTrigger = 'archive_active.trigger'

# Имя файла восстановления - recovery
$FileRecovery = 'recovery.conf'

	#################################
    ###   ВЫЧИСЛЯЕМЫЕ ПАРАМЕТРЫ   ###
    #################################

# признак существования файла $FileTrigger (маркера бэкапирования WAL логов)
# признак уже включенного режима архивации WAL файлов
$IsTrigger = 1

#Список очищаемых папок
$CleanupPaths = @("$PgArchiveNet")

# имя бэкапа
$BackupName = 'postgres_' + $(date -format 'yyyy_MM_dd') + '_cluster.backup'

#Имя Win сервера
$WinServerName = Get-Content env:computername

#Местоположение текущего скрипта
$ScriptFilePath = Split-Path -Parent $MyInvocation.MyCommand.Definition

#Имя файла текущего скрипта
$ScriptFileName = $MyInvocation.MyCommand.Name

#Оставляем только имя
$ScriptfileNameWithoutExt = $ScriptFileName -replace '.ps1'

#Местоположение лога
$LogFileNameFull = $ScriptFilePath + '\Logs\' + $ScriptfileNameWithoutExt + '_-_' + $(date -format 'yyyy-MM-dd') + '.log'

#Местоположение корневой папки со скриптами
$ScriptsRootPath = split-path -parent $ScriptFilePath

#Параметры почтового сервера
$SmtpServer = gc "$ScriptsRootPath\Settings\mail_smtp.txt"
$SmtpPort = gc "$ScriptsRootPath\Settings\mail_port.txt"
$MailTo = gc "$ScriptsRootPath\Settings\mails.txt"

# рассчитываем минимальную дату разрешенного архива
$MinRetentionDate = (Get-Date).AddDays(-$RetentionDays)

#===================================================================================================================
#Перехват любых ошибок и отправка почты
trap
{
	         
    #Текст возникшей ошибки
    $Err = $_.Exception
    $ErrRow = $error[0].InvocationInfo.PositionMessage
	$Text = "$Date - Cтрока: $ErrRow Ошибка: $Err"
	$Date = date -format 'yyyy-MM-dd HH:mm:ss'
	Write-Output $Text >> $LogFileNameFull
	Write-Host $Text
			
	#Продолжительность выполнения скрипта
	$ScriptEndDate = date
	if ([string]$ScriptEndDate.Subtract($ScriptStartDate).Hours -ne "0")
	{
		$TimeElapsed =[string]$ScriptEndDate.Subtract($ScriptStartDate).Hours + " ч, " `
		+ [string]$ScriptEndDate.Subtract($ScriptStartDate).Minutes + " мин, " `
		+ [string]$ScriptEndDate.Subtract($ScriptStartDate).Seconds + " сек"
	}
	elseif ([string]$ScriptEndDate.Subtract($ScriptStartDate).Minutes -ne "0")
	{
		$TimeElapsed =[string]$ScriptEndDate.Subtract($ScriptStartDate).Minutes + " мин, " `
		+ [string]$ScriptEndDate.Subtract($ScriptStartDate).Seconds + " сек"
	}
	else
	{
		$TimeElapsed =[string]$ScriptEndDate.Subtract([DateTime]$ScriptStartDate).Seconds + " сек"
	}
        
    #Тело email сообщения
    $MailMessage = "
    <font face=`"calibri`">
    	$PostrgesDescription завершено с ошибкой:<br>
    	$Text<br>
    	<div style=`"color:#a1a1a1`"> --------------------------------------------------------<br>
        	<strong>Техническая информация:</strong><br>
            <table cellspacing=0 cellpadding=0 border=1 style=`"font-size:0.8em; color:#a1a1a1; border-style:solid; border-color:#a1a1a1`">
            	<tr>
					<td style=`"border-style:solid; border-color:#a1a1a1`">Местоположение скрипта</td>
					<td style=`"border-style:solid; border-color:#a1a1a1`">Сервер скрипта</td>
					<td style=`"border-style:solid; border-color:#a1a1a1`">Время выполнения</td>
				</tr>
            	<tr>
					<td style=`"border-style:solid; border-color:#a1a1a1`">$ScriptFilePath\$ScriptFileName</td>
					<td style=`"border-style:solid; border-color:#a1a1a1`">$WinServerName</td>
					<td style=`"border-style:solid; border-color:#a1a1a1`">$TimeElapsed</td>
				</tr>
			</table>
		</div>
	</font>"

    #Отправка почтового сообщения об ошибкe

	$Date = date -format 'yyyy-MM-dd HH:mm:ss'
	$Text = "$Date - Отправляем письмо о возникших ошибках"
    $TextOut = $Text +':`n'+$err
    Write-Output $TextOut >> $LogFileNameFull
    Write-Host $Text
	
	Send-MailMessage -Encoding UTF8 -Body "$MailMessage" -BodyAsHtml -From "$MailFrom" -SmtpServer "$SmtpServer" -Subject "$MailSubject" -To "$MailTo"

	break
}
#===================================================================================================================

$Date = date -format 'yyyy-MM-dd HH:mm:ss'
Write-Output "==========================================================" >> $LogFileNameFull
Write-Output "========== НАЧАЛО ПРОЦЕССА в $Date =========" >> $LogFileNameFull
Write-Output "==========================================================" >> $LogFileNameFull
Write-Host "=========================================================="
Write-Host "========== НАЧАЛО ПРОЦЕССА в $Date ========="
Write-Host "=========================================================="

# запускаем создание копии WAL файлов перед тем как начать процесс полного бэкапирования.
$cmd = "powershell.exe $ScriptFilePath\..\WAL_Backup\backup_WAL.ps1"
Invoke-Expression $cmd

# чистим рабочий локальный каталог, где будем создавать бэкап
if (Test-Path -Path $PgArchive)
{
	Remove-Item $PgArchive -Recurse -Force
}
New-Item  $PgArchive -itemtype directory 

# чистим рабочий каталог, где копятся WAL файлы, так как мы делаем полный бэкап и старые файлы нам будут не нужны
Remove-Item $PgArchiveWal -Recurse -Force
New-Item  $PgArchiveWal -itemtype directory 


# активируем бэкапирование WAL файлы
if (!(Test-Path -Path $PgData\$FileTrigger))
{
	$IsTrigger = 0
	Write-Output "Activate WAL backup" > $PgData\$FileTrigger
	$Date = date -format 'HH:mm:ss'
	$Text = " $Date - Выполнена активация архивации WAL файлов"
	Write-Output $Text >> $LogFileNameFull
	Write-Host $Text
}

# Формируем копию кластера
$Date = date -format 'HH:mm:ss'
$Text = " $Date - Создаём бэкап кластера по пути: $PgArchive"
Write-Output $Text >> $LogFileNameFull
Write-Host $Text
&"$PgBasebackupFullName" --pgdata="$PgArchive" --format=p --xlog-method=stream --checkpoint=fast --progress --username=postgres --no-password --host=localhost --port=5432 --label=Backup_full  >> "$LogFileNameFull"
if ($LASTEXITCODE -ne 0) 
{
	$Date = date -format 'HH:mm:ss'
	$Text = " $Date - Ошибка при создании бэкапа кластера."
	Write-Output $Text >> $LogFileNameFull
	Write-Host $Text
    throw $Text
}
$Date = date -format 'HH:mm:ss'
$Text = " $Date - Бэкап кластера создан."
Write-Output $Text >> $LogFileNameFull
Write-Host $Text

# создаем файл восстановления 
Out-File -FilePath $PgArchive\$FileRecovery -Encoding "OEM" -inputobject "# PostgreSQL recovery config file"
Out-File -FilePath $PgArchive\$FileRecovery -Encoding "OEM" -Append -inputobject "restore_command = ''"
Out-File -FilePath $PgArchive\$FileRecovery -Encoding "OEM" -Append -inputobject "#recovery_target_time = ''	# e.g. '2004-07-14 22:39:00 EST"

# прибираемся немного
Remove-Item $PgArchive\pg_log -Recurse  -Force
New-Item  $PgArchive\pg_log -itemtype directory 
if ($IsTrigger -eq 0) 
{
	# отключаем бэкапирование WAL файлов так как мы его включали
	Remove-Item $PgArchive\$FileTrigger
	Remove-Item $PgData\$FileTrigger
}

# выполняем архивацию
$Date = date -format 'HH:mm:ss'
$Text = " $Date - Создаём архив: $PgArchive\$BackupName.$ArcProgramExt"
Write-Output $Text >> $LogFileNameFull
$cmd = "& `"{0}`" {1} `"{2}\{3}.{4}`" `"{5}\`" >> `"{6}`"" -f $ArcProgram, $ArcProgramParam, $PgArchive, $BackupName, $ArcProgramExt, $PgArchive, $LogFileNameFull
Invoke-Expression $cmd
if (!(Test-Path -Path $PgArchive\$BackupName.$ArcProgramExt)) 
{
	$Date = date -format 'HH:mm:ss'
	$Text = " $Date - Ошибка при создании архивного файла."
	Write-Output $Text >> $LogFileNameFull
	Write-Host $Text
    throw $Text
}
$Date = date -format 'HH:mm:ss'
$Text = " $Date - Файл архива создан: $PgArchive\$BackupName.$ArcProgramExt"
Write-Output $Text >> $LogFileNameFull
Write-Host $Text

# копируем на сетевое устройство 
$Text = " $Date - Копируем архив на бэкапное хранилище: $PgArchiveNet\$BackupName.$ArcProgramExt"
Write-Output $Text >> $LogFileNameFull
Write-Host $Text
Copy-Item "$PgArchive\$BackupName.$ArcProgramExt" -Destination $PgArchiveNet\ -ErrorAction Stop -Force
if (!(Test-Path -Path $PgArchiveNet\$BackupName.$ArcProgramExt)) 
{
	$Date = date -format 'HH:mm:ss'
	$Text = " $Date - Ошибка при копировании файла на сетевое устройство."
	Write-Output $Text >> $LogFileNameFull
	Write-Host $Text
    throw $Text
}
$Date = date -format 'HH:mm:ss'
$Text = " $Date - Файл архива скопирован на сетевое устройство: $PgArchiveNet\"
Write-Output $Text >> $LogFileNameFull
Write-Host $Text

# выполняем удаление старых архивов
$Date = date -format 'HH:mm:ss'
$Text = " $Date - проверяем необходимость удаления старых архивов"
Write-Output $Text >> $LogFileNameFull
Write-Host $Text
foreach ($CleanupPath in $CleanupPaths)
{

    #Дата самого старого полного бэкапа
    $OldestFullBackupDate = (Get-ChildItem -File $CleanupPath) `
        | where {($_.CreationTime -gt $MinRetentionDate) -and ($_.Name+'.'+$_.Extension -match '.backup.7z')} `
        | Sort-Object CreationTime

    if (!$OldestFullBackupDate)
    {
        continue
    }
    $OldestFullBackupDate = ($OldestFullBackupDate | Select-Object -First 1)[0].CreationTime
    $OldestFullBackupDateText = "{0:yyyy-MM-dd HH:mm:ss}" -f $OldestFullBackupDate

    $Date = date -format 'HH:mm:ss'
    $Text = " $Date - Удаляем бэкапы старше $OldestFullBackupDateText из папки $CleanupPath"
    Write-Output $Text >> $LogFileNameFull
    Write-Host $Text

    $FoldersToRemove = (Get-ChildItem -File $CleanupPath) `
        | where {($_.CreationTime -lt $OldestFullBackupDate) -and ($_.Name+'.'+$_.Extension -match '.backup.')}

    foreach ($FolderToRemove in $FoldersToRemove)
    {
        Remove-Item $($FolderToRemove.FullName) -Recurse -Force
        $Date = date -format 'HH:mm:ss'
        $Text = " $Date - Удален бэкап $($FolderToRemove.Name)"
        Write-Output $Text >> $LogFileNameFull
        Write-Host $Text
    }
}

$Date = date -format 'yyyy-MM-dd HH:mm:ss'
Write-Output "==========================================================" >> $LogFileNameFull
Write-Output "=========== КОНЕЦ ПРОЦЕССА в $Date =========" >> $LogFileNameFull
Write-Output "==========================================================" >> $LogFileNameFull
Write-Host "=========================================================="
Write-Host "=========== КОНЕЦ ПРОЦЕССА в $Date ========="
Write-Host "=========================================================="
