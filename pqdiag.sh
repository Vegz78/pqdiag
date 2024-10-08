#!/bin/bash
MAX_TIME=5
CONNECT_TIMEOUT=5

if [[ $1 =~ ^((25[0-5]|(2[0-4]|1[0-9]|[1-9]|())[0-9])\.){3}((25[0-5]|(2[0-4]|1[0-9]|[1-9]|())[0-9]))$ ]]; then
	echo "Sending print quality diagnostics job to HP_printer@$1!"
	curl --max-time $MAX_TIME --connect-timeout $CONNECT_TIMEOUT -H "User-Agent:" -H "Host: localhost" -H "Accept:" -H "X-HP-AR-INFO: chunk-correct" -H "Content-Type: text/xml" -H "Content-Length: 220" --data-binary "<?xml version=\"1.0\" encoding=\"UTF-8\"?><ipdyn:InternalPrintDyn xmlns:ipdyn=\"http://www.hp.com/schemas/imaging/con/ledm/internalprintdyn/2008/03/21\"><ipdyn:JobType>pqDiagnosticsPage</ipdyn:JobType></ipdyn:InternalPrintDyn>" --http1.1 http://$1:8080/DevMgmt/InternalPrintDyn.xml 2> /dev/null
	if [[ $? == 0 ]];then
		echo "PQ diagnostics printed OK!"
		exit 0
	else
		echo "PQ diagnostics did NOT print!"
		exit 1
	fi
	exit 1
else
	echo "The argument \"$1\" is not a valid IPv4 address or missing..."
	echo "Please try again like this: ./pqdiag.sh 192.0.0.10"
	echo "(Using your HP printer's IP address)"
	exit 1
fi
exit 1
