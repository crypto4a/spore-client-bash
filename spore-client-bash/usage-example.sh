#!/bin/bash

# Import utils
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

url='rootofqaos.com/eaasp'


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

convert_base64url() {
    arg=$1
    local length=$((${#arg} % 4))
    [[ $length == 2 ]] && arg=$arg==
    [[ $length == 3 ]] && arg=$arg=
    echo $arg | tr '_-' '/+'
}


# =====================
# Convert raw signature to DER
# =====================
der_encode() {
    # Convert binary data into hex string
    hex=$(xxd -p -c 300)
    hex_arr=($(echo $hex | grep -o ..))
    padR=false
    padS=false

    if [[ ${hex_arr[0]} > "7f" ]]; then
        padR=true
    fi
    if [[ ${hex_arr[32]} > "7f" ]]; then
        padS=true
    fi

    file="/tmp/signature_der.$$"
    printf "%b" "\x30" > $file

    # Length, R and S each has 32 byte. Each has 1 byte tag and length.
    totalLen=68
    if $padR ; then
        let totalLen++
    fi
    if $padS ; then
        let totalLen++
    fi
    totalLenHex=$(printf "%x" $totalLen)
    printf "%b" "\x$totalLenHex" >> $file

    # R tag
    printf "%b" "\x02" >> $file
    # R length 32
    RLen=32;
    if $padR ; then
        let RLen++;
    fi
    RLenHex=$(printf "%x" $RLen)
    printf "%b" "\x$RLenHex" >> $file
    # R
    if $padR ; then
        printf "%b" "\x00" >> $file
    fi

    for i in {0..31}
        do
            printf "%b" "\x${hex_arr[$i]}" >> $file
        done

    # S tag
    printf "%b" "\x02" >> $file
    # S length 32
    SLen=32;
    if $padS ; then
        let SLen++;
    fi
    SLenHex=$(printf "%x" $SLen)
    printf "%b" "\x$SLenHex" >> $file
    # R
    if $padS ; then
        printf "%b" "\x00" >> $file
    fi

    for i in {32..63}
        do
            printf "%b" "\x${hex_arr[$i]}" >> $file
        done
}

# Testing and getting entropySize
entropySize=$(./spore.sh -i $url | jq -r '.entropySize')
name=$(./spore.sh -i $url | jq -r '.name')

# Generating b64url challenge
challenge=$(dd status=none if=/dev/urandom bs=16 count=1)
b64challenge=$(echo $challenge | base64url_encode)

# Performing getEntropy request
entropyResponse=$(./spore.sh -e $b64challenge $url)

# Seeding local entropy
rxEntropy=$(echo $entropyResponse | jq -r '.entropy')
base64url_decode $rxEntropy > /dev/urandom
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

# The signature returned by JWT (e.g. ES256, ES384) is a simple concatenation
# of R and S. OpenSSL requires DER encoding of the signature. So we need
# to encode the raw signature into DER before passing to OpenSSL.
convert_base64url ${jwt[2]} | base64 -d  > /tmp/signature.$$
der_encode < /tmp/signature.$$

pk=$(./spore.sh -c $url | jq -r '.certificateChain' | openssl x509 -pubkey -noout)
echo -n ${jwt[0]}.${jwt[1]} | openssl dgst -sha384 -verify <(echo "$pk") \
-signature /tmp/signature_der.$$

claims=$(base64url_decode ${jwt[1]})
sigEntropy=$(echo "$claims" | jq -r '.entropy')
sigChallenge=$(echo "$claims" | jq -r '.challenge')
sigTimestamp=$(echo "$claims" | jq -r '.timestamp')
[[ "$sigEntropy" == $rxEntropy ]] ||
err Signed entropy does not match received entropy &&
exit 1
[[ $sigChallenge == $rxChallenge ]] ||
err Signed challenge does not match received challenge &&
exit 1
[[ $sigTimestamp == $rxTimestamp ]] ||
err Signed timestamp does not match received timestamp &&
exit 1