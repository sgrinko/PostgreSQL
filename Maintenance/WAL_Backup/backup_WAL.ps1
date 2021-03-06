﻿##############################################################################
#
# Версия - 1.0
#
##############################################################################
# 
# Выполняет архивирование WAL файлов кластера БД
# имя архива будет: postgres_YYYY_MM_DD_cluster.backup.WAL.7z
# Архив сохраняется по пути: PGARCHIVE_NET
#  ________________________________________________________________________________
# | Дата изменения |   Кто изменял    | Версия скрипта | Причины изменения
# |________________________________________________________________________________
# |   21.09.2015   |  Гринько Сегей   |     1.0        | Создание данного скрипта
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

# каталог создания копии кластера
$PgArchive = 'D:\Backup\PostgreSQL\BAK'
# сетевой каталог хранения бэкапа
$PgArchiveNet = '\\my_backup\PostgreSQL\MCHSDB'
# сетевой каталог хранения копий WAL файлов
$PgArchiveWal = '\\my_backup\PostgreSQL\WAL'

# программа архивации
$ArcProgram = 'C:\Program Files\7-Zip\7z.exe'
# расширение файла архива
$ArcProgramExt = '7z'
$ArcProgramParam = 'a -r -mx=5'

#Описание сервера Postrges для использования в письмах
$PostrgesDescription = 'MYDB01'

#Тема сообщения об ошибке
$MailSubject = "Создание WAL бэкапа $PostrgesDescription"
 
#Параметры почтового сервера
$MailFrom = 'MYDB@email.ru'

	#################################
    ###   ВЫЧИСЛЯЕМЫЕ ПАРАМЕТРЫ   ###
    #################################

# признак существования файла $FileTrigger (маркера бэкапирования WAL логов)
# признак уже включенного режима архивации WAL файлов
$IsTrigger = 1

#Список очищаемых папок
$CleanupPaths = @("$PgArchiveNet")

# имя бэкапа
$BackupName = 'postgres_' + $(date -format 'yyyy_MM_dd') + '_cluster.backup.wal'

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


# выполняем архивацию
$Date = date -format 'HH:mm:ss'
$Text = " $Date - Создаём архив: $PgArchive\$BackupName.$ArcProgramExt"
Write-Output $Text >> $LogFileNameFull
$cmd = "& `"{0}`" {1} `"{2}\{3}.{4}`" `"{5}\`" >> `"{6}`"" -f $ArcProgram, $ArcProgramParam, $PgArchive, $BackupName, $ArcProgramExt, $PgArchiveWal, $LogFileNameFull
Invoke-Expression $cmd
if (!(Test-Path -Path "$PgArchive\$BackupName.$ArcProgramExt")) 
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
if (!(Test-Path -Path "$PgArchiveNet\$BackupName.$ArcProgramExt")) 
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

# чистим за собой. Удаляем бэкап предыдущего дня, так как текущий покрывает всё
$Date = (Get-Date).adddays(-1) #вчерашняя дата
$Date = Get-Date $Date -f 'yyyy_MM_dd'
$BackupName = 'postgres_' + $Date + '_cluster.backup'
if (Test-Path -Path "$PgArchiveNet\$BackupName.wal.$ArcProgramExt") 
{
	Write-Host "$PgArchiveNet\$BackupName.$ArcProgramExt"
	if (!(Test-Path -Path "$PgArchiveNet\$BackupName.$ArcProgramExt"))
	{
		Remove-Item "$PgArchiveNet\$BackupName.wal.$ArcProgramExt" -Force
		$Date = date -format 'HH:mm:ss'
		$Text = " $Date - Удален бэкап $PgArchiveNet\$BackupName.wal.$ArcProgramExt"
		Write-Output $Text >> $LogFileNameFull
		Write-Host $Text
	}
}
if (Test-Path -Path "$PgArchive\$BackupName.wal.$ArcProgramExt")
{
	if (!(Test-Path -Path "$PgArchive\$BackupName.$ArcProgramExt"))
	{
		Remove-Item "$PgArchive\$BackupName.wal.$ArcProgramExt" -Force
		$Date = date -format 'HH:mm:ss'
		$Text = " $Date - Удален бэкап $PgArchive\$BackupName.wal.$ArcProgramExt"
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
