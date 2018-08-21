#!/bin/bash -e

# ===========
# PRINT ERROR
# ===========
err() {
    echo -e "\033[0;31mERROR: $@\033[0m" >&2
}

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

# =========
# MAIN CODE
# =========

# Load config
if test -f /usr/local/etc/spore/spore.conf; then
    . /usr/local/etc/spore/spore.conf
fi

# Validate challenge size.
if [ $challenge -lt 0 ]; then
    err "Invalid challenge size value, can not be smaller than 0."
    exit 1
fi
if [ $challenge -gt 64 ]; then
    err "Invalid challenge size value, can not be greater than 64."
    exit 1
fi

# Validate freshness window.
if [ $fressnessWindow -lt 0 ]; then
    err "Invalid freshness window value, can not be smaller than 0."
    exit 1
fi

# Generating b64url challenge
if [ $challenge -eq 0 ]; then
    b64challenge=""
else    
    challenge=$(dd status=none if=/dev/urandom bs=$challenge count=1)
    b64challenge=$(echo $challenge | base64url_encode)
fi

# Performing getEntropy request
entropyResponse=$(./spore -e $b64challenge $server)

# Verify signature if specified
if [[ $verify == True ]]; then
    jwt=($(echo $entropyResponse | jq -r '.JWT' | tr '.' ' '))
    
    pk=$(./spore -c $server | 
    jq -r '.certificateChain' | 
    openssl x509 -pubkey -noout)

    echo -n ${jwt[0]}.${jwt[1]} | 
    openssl dgst -sha256 -verify <(echo "$pk") \
    -signature <(base64url_decode ${jwt[2]})

    if [ $? -ne 0 ]; then
        err "Verification failed."
        exit 1
    fi

    claims=$(base64url_decode ${jwt[1]})
    rxEntropy=$(echo "$claims" | jq -r '.entropy')
    rxChallenge=$(echo "$claims" | jq -r '.challenge')
    rxTimestamp=$(echo "$claims" | jq -r '.timestamp')
else    
    rxEntropy=$(echo $entropyResponse | jq -r '.entropy')
    rxChallenge=$(echo $entropyResponse | jq -r '.challenge')
    rxTimestamp=$(echo $entropyResponse | jq -r '.timestamp')
fi

# Verify freshness
if [ $freshnessWindow -ne 0 ]; then
    localTime=$(date +%s)
    ((diff = $rxTimestamp - $localTime))
    diff=${diff#-}
    if (( diff > freshWindow )); then
        err "Freshness verification failed."
        exit 1
    fi
fi

# Verify challenge
if [ -z $b64challenge ]; then
    if [[ $b64challenge != $rxChallenge ]]; then
        err "Challenge verification failed."
        exit 1
    fi
fi

# Seeding local entropy
entropy=$(base64url_decode $rxEntropy)
echo $entropy > /dev/urandom