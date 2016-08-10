#!/usr/bin/env bash
API_DOCS=https://dev.twitter.com/rest/reference
ENDPOINTS=$(cat endpoints.txt)
# ENDPOINTS="POST statuses/destroy/:id"
# ENDPOINTS="GET search/tweets"
# ENDPOINTS="GET lists/subscriptions"
# ENDPOINTS="GET lists/members/show"
# ENDPOINTS="POST account/settings"

echo "$ENDPOINTS" |
while read endpoint; do
  url=$(echo $endpoint | tr '[:upper:]' '[:lower:]' | tr ' ' '/')
  verb=$(echo $endpoint | sed -e 's| .*$||' | tr '[:upper:]' '[:lower:]')
  kabob=$(echo $endpoint | tr '[:upper:]' '[:lower:]' | tr ' /_' '-' | tr -d ':')
  group=$(echo $endpoint | sed -e 's|^.* ||' -e 's|/.*||')
  camel=$(echo $kabob | perl -pe 's/\b(\w)/\U$1/g; s/-//g')
  urlCall=$(echo $url | perl -pe "s|^.*?/||; s|^|'|; s|$|'|; s|:([\w_]+)|' + data.\$1 + '|; s| \+ ''$||;")

  echo ------------------------------

  deprecated=$(pup 'title text{}' <api/$kabob.txt | grep -i deprecated)
  if [[ -n "$deprecated" ]]; then
    echo $deprecated
    continue
  fi

  echo $endpoint - $group
  # echo $url / $kabob / $camel

  if [[ ! -f api/$kabob.txt ]]; then
    curl "${API_DOCS}/$url" --create-dirs --silent --output api/$kabob.txt
  fi
  numParams=$(pup -n 'div.parameter' <api/$kabob.txt)
  # echo $numParams
  if [[ $numParams -gt 0 ]]; then
    requiredChecks=""
    requiredProperties=""
    properties=""
    formData=""$'\n'

    for i in $(seq 1 $numParams); do
      # pup "div.parameter:nth-of-type($i)" <api/$kabob.txt
      numCode=$(pup -n "div.parameter:nth-of-type($i) p:last-of-type code" <api/$kabob.txt)
      code=$(pup "div.parameter:nth-of-type($i) p:last-of-type code text{}" <api/$kabob.txt)
      # echo $code
      param=$(pup "div.parameter:nth-of-type($i) span.param text{}" <api/$kabob.txt)
      name=$(echo "$param" | sed -n '1p' | tr -d ' ')
      friendlyName=$(echo "$name"| perl -pe ' s/_/ /g; s/\b(\w)/\U$1/g; s/\bId\b/ID/;')
      required=$(echo "$param" | sed -n '2p' | tr -d ' ')
      helpText=$(pup "div.parameter:nth-of-type($i) p:first-of-type text{}" <api/$kabob.txt | tr -d '\n' | sed -e 's|Optional. ||' | perl -pe 's/^(.{10,}?\.).*$/$1/')

      if [[ "$friendlyName" == "Q" ]]; then
        friendlyName="Query"
      fi

      # if [[ "$name" == "slug" ]] || [[ "$name" == "lang" ]]; then
      #   codeType="string"
      # el
      if [[ "$name" == "count" ]]; then
        codeType="integer"
      elif [[ "$name" == "cursor" ]]; then
        codeType="string"
      elif [[ "$code" == "true"  ]] || [[ "$code" = 'true'$'\n'$'t'$'\n'$'1'  ]] ||
           [[ "$code" == "false" ]] || [[ "$code" = 'false'$'\n'$'f'$'\n'$'0' ]] ||
           [[ "$code" = 'true'$'\n'$'false' ]]; then
        codeType="boolean"
      # elif [[ $numCode -gt 1 ]]; then
      #   codeType="enum"
      else
        codeType="string"
      fi

      if [[ "$required" == "required" ]]; then
        requiredChecks+="    return callback \@_userError(422, '${friendlyName} is required') unless data.${name}?"$'\n'
        requiredProperties+="${name} "
      fi
      properties+="        '$name':"$'\n'
      properties+="          type: '$codeType'"$'\n'
      properties+="          title: '$friendlyName'"$'\n'
      properties+="          description: '$helpText'"$'\n'

      formData+="    'data.$name'"$'\n'
      # echo "($friendlyName) $name:$required:$codeType:$numCode:($code) - $helpText"
      # exit
    done
    # echo "$requiredChecks"
  fi
  # exit

  mkdir -p jobs/$kabob
  cp -rp template-job/* jobs/$kabob
  perl -pe "s|\{\{JobName\}\}|$camel|" -i jobs/$kabob/job.coffee
  perl -pe "s|\{\{requiredChecks\}\}|$requiredChecks|" -i jobs/$kabob/job.coffee
  perl -pe "s|\{\{verb\}\}|$verb|" -i jobs/$kabob/job.coffee
  perl -pe "s|\{\{urlCall\}\}|$urlCall|" -i jobs/$kabob/job.coffee

  requiredProperties=$(echo $requiredProperties | perl -pe "s|^|'|; s|\$|'|; s| +\$||; s| |', '|g; s|''|'|g; s|^'*\$||;")
  perl -pe "s|\{\{requiredProperties\}\}|$requiredProperties|" -i jobs/$kabob/message.cson
  perl -pe "s|\{\{properties\}\}|$properties|" -i jobs/$kabob/message.cson
  perl -pe "s|\{\{title\}\}|$endpoint|" -i jobs/$kabob/message.cson
  perl -pe "s|\{\{groupName\}\}|$group|" -i jobs/$kabob/message.cson

  perl -pe "s|\{\{formData\}\}|$formData|" -i jobs/$kabob/form.cson
done
