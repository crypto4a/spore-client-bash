[[ -z $1 ]] && echo Error: Must provide path to makeself.sh && exit 1

msg="Spore Service to seed local entorpy source on startup"
$1 ./ spore-client-service $msg ./install.sh
rm ../release/* 2> /dev/null
mv spore-client-service ../release/spore-client-service
