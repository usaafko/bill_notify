function printTicket{
    param($config,$count_tickets,$unread_tickets,[string[]]$text)
    # Create text from array
    $printtext = '';
    foreach ($t in $text) {
        $printtext += "- " + $t + "`n"; 
    }

    if (Get-Process logon*) { 
                    
        ## If we on logon screen - send telegram message instead of notify

        $payload= @{"chat_id"=$config.chatid; "text"= '```'+$printtext+'```'; "parse_mode"="Markdown"; }
        Invoke-WebRequest -Uri ("https://api.telegram.org/bot" + $config.token + "/sendMessage") -Method Post -ContentType "application/json; charset=utf-8" -Body (ConvertTo-Json -Compress -InputObject $payload)

    }else{

        New-BurntToastNotification -AppId 'my.ispsystem.com' -Text ("Всего тикетов: " + $count_tickets + " Непрочитанных: " + $unread_tickets), $printtext -AppLogo C:\Users\ilya\Documents\ticket.jpg
        echo "run toast`n $printtext";
    }
}

## future check
## ( (Invoke-WebRequest -Uri 'http://wiki.ispsystem.net/door.py').Content -split "<tr>" | Where {$_ -match '2036834'} ) -match 'bgcolor="#93c195"'
## Load config file
$config = ConvertFrom-Json -InputObject (get-content 'config.bill') 

## Create new WebClient
$wc = New-Object Net.WebClient
$wc.Encoding = [System.Text.Encoding]::UTF8
$app = New-BTAppId -AppId 'my.ispsystem.com'

## Authenticate and get a session ID:
[xml]$auth = $wc.DownloadString(("{0}&func=auth&username={1}&password={2}" -f $config.url,$config.user,$config.pass))
#echo $auth
## Create Job Body
$text = ''
while ($true) {

		## Now get client ticket list:
		[xml]$tickets = $wc.DownloadString(("{0}&func=ticket&auth={1}" -f $config.url,$auth.doc.auth.id))

		## Find error:
		$api_error = $tickets.doc.error
		if ($api_error) {
			New-BurntToastNotification -Text "Ошибка", "Ошибка запроса к биллингу $api_error.msg"
			exit
		}

		#$unread_tickets = $tickets.doc.SelectNodes('./elem')
        $unread_tickets = $tickets.doc.SelectNodes('./elem[contains(unread,"on")]')
        $count_tickets = $tickets.doc.SelectNodes('./elem').count

		## Print ticket list to notify:
		if ($unread_tickets.count -gt 0) {

            # Create array of tickets
			$oldtext = $text
            $text = @()
			foreach ($ticket in $unread_tickets) {
				if (-Not $ticket.blocked_by) { $text += $ticket.name }
			}

			if ($text.Length -gt 0) {
                # Compare old and new array
                $compare = $text | Where {$oldtext -notcontains $_}
                if ($compare.Length -gt 0) { 
                    echo "run print`n $compare"    
                    printTicket $config $count_tickets $unread_tickets.Count $compare
                }
			}
		} else {
            $text = @()
        }
		## Do 15 second sleep
		Start-Sleep -s 15
}

