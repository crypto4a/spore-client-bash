#!/bin/bash

# Import utils
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

url='127.0.0.41:8099/eaasp'


# ===================
# ENCODE TO BASE64URL
# ===================
base64url_encode() {
    base64 -w 0 | tr -d '=' | tr '+/' '-_'
}

# =====================
# DECODE FROM BASE64URL
# =====================
base64url_decode() {
    arg=$1
    local length=$((${#arg} % 4))
    [[ $length == 2 ]] && arg=$arg==
    [[ $length == 3 ]] && arg=$arg=
    echo $arg | tr '_-' '/+' | base64 --decode
}


# Testing and getting entropySize
entropySize=$(./spore -i $url | jq -r '.entropySize')
name=$(./spore -i $url | jq -r '.name')

# Generating b64url challenge
challenge=$(dd status=none if=/dev/urandom bs=16 count=1)
b64challenge=$(echo $challenge | base64url_encode)

# Performing getEntropy request
entropyResponse=$(./spore -e $b64challenge $url)

# Seeding local entorpy
rxEntropy=$(echo $entropyResponse | jq -r '.entropy')
entropy=$(base64url_decode $rxEntropy)
echo $entropy > /dev/urandom
echo Successfully seeded /dev/urandom

# Verifying challenge
rxChallenge=$(echo $entropyResponse | jq -r '.challenge')
if [[ $b64challenge == $rxChallenge ]]
then
    echo Challenges match
else
    err Challenges do not match
    exit 1
fi

# Verifying freshness
rxTimestamp=$(echo $entropyResponse | jq -r '.timestamp')
localTime=$(date +%s)
freshWindow=60
((diff = $rxTimestamp - $localTime))
diff=${diff#-}
if (( diff <= freshWindow ))
then
    echo Entropy response is fresh
else
    err Entropy response is not fresh
    exit 1
fi

# Authenticating the response
jwt=($(echo $entropyResponse | jq -r '.JWT' | tr '.' ' '))
pk=$(./spore -c $url | jq -r '.certificateChain' | openssl x509 -pubkey -noout)
echo -n ${jwt[0]}.${jwt[1]} | openssl dgst -sha256 -verify <(echo "$pk") \
-signature <(base64url_decode ${jwt[2]})

claims=$(base64url_decode ${jwt[1]})
sigEntropy=$(echo "$claims" | jq -r '.entropy')
sigChallenge=$(echo "$claims" | jq -r '.challenge')
sigTimestamp=$(echo "$claims" | jq -r '.timestamp')
[[ "$sigEntropy" == $rxEntropy ]] || 
err Signed entropy does not match received entorpy && 
exit 1
[[ $sigChallenge == $rxChallenge ]] ||
err Signed challenge does not match received challenge &&
exit 1
[[ $sigTimestamp == $rxTimestamp ]] ||
err Signed timestamp does not match received timestamp &&
exit 1