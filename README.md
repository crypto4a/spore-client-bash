# Spore Client Bash
A Bash implementation of the Spore Protocol (Add link to the REST API here).

## Installation

## Requirements
The **Spore** program makes use of the following programs:
- [jq](https://stedolan.github.io/jq/)
- [OpenSSL](https://www.openssl.org/)
- [cURL](https://curl.haxx.se/)

## Known Spore Servers<a name="known-spore-servers">
- rootofqaos.com
- rootofentropy.com
- entropy.2keys.io

## Usage
### Choose a server
Any of the servers from the [Known Spore Servers](#known-spore-servers) section offer good quality entropy through the Spore Protocol.

### Testing the Connection
A simple way of testing the connection is to simply send a `getInfo` request. This will also give us basic information on the server, namely it's name and the quantity of the entropy it serves.
```
entropySize=$(spore -i $url | jq -r '.entropySize')
```

### Requesting Entropy
Now that we know the connection is working, we can request entropy from the server. If we care about verifying the validity of the response, we should send a challenge, however, this is not required.

- With a challenge
```
challenge=$(dd status=none if=/dev/urandom bs=16 count=1)
b64challenge=$(echo $challenge |
    base64 -w 0 |
    tr -d '=' |
    tr '+/' '-_')
entropyResponse=$(spore -e $b64challenge $url)
```
Here, a random challenge is generated. This is the best practice to avoid repeating the challenge. If a large number of requests are expected to be sent, increasing the length of the challenge would decrease the probability of challenge collisions.

- Without a challenge
```
entropyResponse=$(spore -e "" $url)
```

### Adding the Entropy to our System
Now that we received good quality entropy, we can seed our local source of randomness. It is best practice to first perform some hash to combine the received entropy with some local entropy. Indeed, if one was to simply seed it local entropy source with compromised entropy, the system would become deterministic to the malicious party.

In linux, when writing to /dev/urandom (the local source of randomness), the system actually adds to the pool of already existing randomness.
```
entropy=$(echo $entropyResponse | jq -r '.entropy')
entropy=$(base64url_decode $entropy)
echo $entropy > /dev/urandom
echo Successfully seeded /dev/urandom
```

Many IoT devices with extremely limited resources would stop here, now having an entropy pool at worst similar to before the operation and at best of high quality. However, some devices with more resources or with tasks critically relying on cryptographic security will want to verify and authenticate the entropy.

### Verifying the Challenge
The first obvious step is to confirm that the entropy was indeed generated for our request, and not anyone else's. To do that, we can simply make sure the returned challenge matches the one we sent.
```
rxChallenge=$(echo $entropyResponse | jq -r '.challenge')
if [[ $b64challenge == $rxChallenge ]]
then
    echo Challenges match
else
    echo Challenges do not match
fi
```

### Verifying the Freshness
Another verification that can be made is to verify the entropy sent is fresh. This can easily be done with the help of the returned timestamp.
```
timestamp=$(echo $entropyResponse | jq -r '.timestamp')
localTime=$(date +%s)
freshWindow=60
((diff = $timestamp - $localTime))
diff=${diff#-}
if (( diff <= freshWindow ))
then
    echo Entropy response is fresh
else
    echo Entropy response is not fresh
fi
```

Here, we allow a one minute window.

### Authetication the Response
Using the JWT received in the response, we can authenticate it using the server's public signature. If it is not known, it can be obtained with a `getCertChain` request.
```
jwt=($(echo $entropyResponse | jq -r '.JWT' | tr '.' ' '))
pk=$(./spore -c $url | jq -r '.certificateChain' | openssl x509 -pubkey -noout)
printf '%s' $pk
cat <<< "$pk"
echo -n "$pk"
echo -n ${jwt[0]}.${jwt[1]} | openssl dgst -sha256 -verify <(echo "$pk") \
-signature <(base64url_decode ${jwt[2]})
```

At this point we know the signature is valid. We should now cross validate the
received data with the data contained in the JWT. A device that performs
authentication could also verify the signature and extract the received data
directly from the JWT. This way, the next verification step would not be
necessary.
```
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
```

## Issue Reporting
If you found a bug, have a feature request, or a design recommendation, please open a new issue at this repository's [issues section](https://github.com/crypto4a/spore-client-bash/issues). If you find a security vulnerablility, please do not report it on the public GitHub issue tracker but instead contact [Crypto4a](https://crypto4a.com/contact-crypto4a/) directly.

## Author
[Crypto4a](https://crypto4a.com/)
