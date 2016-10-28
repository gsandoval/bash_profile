alias git-tree="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset [%an]' --abbrev-commit --date=relative"
alias gps="git push"
alias gpst="git push --tags"
alias gpl="git pull"
alias gco="git checkout"
alias gcm="git commit"
alias gd="git diff"
alias gl="git log"
alias gs="git status"
alias ga="git add"
alias gm="git merge"
alias gt="git tag --sort version:refname"
alias gba="git branch -a"
alias gb="git branch"
alias gf="git fetch origin --tags --prune"
alias gmno="git merge --no-ff"

ec2_cert_path=/path/to/your/certs

ec2search ()
{
        result=`aws ec2 describe-instances --filters "Name=tag:Name,Values=*$1*" --output=json --query 'Reservations[*].Instances[0].[Tags[?Key==\`Name\`] | [0].Value, NetworkInterfaces[0].PrivateIpAddresses[0].PrivateIpAddress, KeyName, State.Name]' | jq '[.[] | { instanceName: .[0], ipAddress: .[1], keyName: .[2], state: .[3] }]'`
        ec2printresults "$result"
}

ec2printresults ()
{
        result="$1"
        result_count=`echo $result | jq '. | length'`
        for i in `seq 1 $result_count`; do
                index=`expr $i - 1`
                instance_name=`echo $result | jq ".[$index] | .instanceName"`
                ip_address=`echo $result | jq ".[$index] | .ipAddress"`
                key_name=`echo $result | jq ".[$index] | .keyName"`
                state=`echo $result | jq ".[$index] | .state"`
                printf "%-3s %-30s %-30s %-20s %-10s\n" "$index" "$instance_name" "$ip_address" "$key_name" "$state"
        done
}

ec2copy()
{
        file=$1
        server=$2
        username=`echo $server | awk 'match($0,"@"){print substr($1,0,RSTART-1)}'`
        if [ -z "$username" ]; then
                username=ec2-user
        else
                server=`echo $server | sed "s/$username@//"`
        fi

        dest_path=`echo $server | awk 'match($0,":"){print substr($1,RSTART+1)}'`
        if [ -z "$dest_path" ]; then
                dest_path="~/"
        else
                sed_dest_path=${dest_path/\//\\\/}
                server=`echo $server | sed "s/:$sed_dest_path//"`
        fi

        result=`aws ec2 describe-instances --filters "Name=tag:Name,Values=*$server*" --output=json --query 'Reservations[*].Instances[0].[Tags[?Key==\`Name\`] | [0].Value, NetworkInterfaces[0].PrivateIpAddresses[0].PrivateIpAddress, KeyName, State.Name]' | jq '[.[] | { instanceName: .[0], ipAddress: .[1], keyName: .[2], state: .[3] }]'`
        result_count=`echo $result | jq '. | length'`

        if [ "$result_count" -eq "0" ]; then
                echo "no instance found."
                return
        fi

        result_index_selection="0"
        if [ "$result_count" -gt "1" ]; then
                if [ -z "$3" ]; then
                        ec2printresults "$result"
                        echo "Select server [0-$((result_count - 1))]"
                        read result_index_selection
                else
                        $result_index_selection=$2
                fi
        fi

        instance_name=`echo $result | jq -r ".[$result_index_selection] | .instanceName"`
        ip_address=`echo $result | jq -r ".[$result_index_selection] | .ipAddress"`
        key_name=`echo $result | jq -r ".[$result_index_selection] | .keyName"`
        state=`echo $result | jq -r ".[$result_index_selection] | .state"`

        echo "Copying to $instance_name..."
        echo "scp -i $ec2_cert_path$key_name.pem $file $username@$ip_address:$dest_path"
        scp -i $ec2_cert_path$key_name.pem $file $username@$ip_address:$dest_path
}

ec2connect()
{
        server=$1
        username=`echo $1 | awk 'match($0,"@"){print substr($1,0,RSTART-1)}'`
        if [ -z "$username" ]; then
                username=ec2-user
        else
                server=`echo $server | sed "s/$username@//"`
        fi

        result=`aws ec2 describe-instances --filters "Name=tag:Name,Values=*$server*" --output=json --query 'Reservations[*].Instances[0].[Tags[?Key==\`Name\`] | [0].Value, NetworkInterfaces[0].PrivateIpAddresses[0].PrivateIpAddress, KeyName, State.Name]' | jq '[.[] | { instanceName: .[0], ipAddress: .[1], keyName: .[2], state: .[3] }]'`
        result_count=`echo $result | jq '. | length'`

        if [ "$result_count" -eq "0" ]; then
                echo "no instance found."
                return
        fi

        result_index_selection="0"
        if [ "$result_count" -gt "1" ]; then
                if [ -z "$2" ]; then
                        ec2printresults "$result"
                        echo "Select server [0-$((result_count - 1))]"
                        read result_index_selection
                else
                        $result_index_selection=$2
                fi
        fi

        instance_name=`echo $result | jq -r ".[$result_index_selection] | .instanceName"`
        ip_address=`echo $result | jq -r ".[$result_index_selection] | .ipAddress"`
        key_name=`echo $result | jq -r ".[$result_index_selection] | .keyName"`
        state=`echo $result | jq -r ".[$result_index_selection] | .state"`

        echo "Connecting to $instance_name..."
        echo "ssh $username@$ip_address -i $ec2_cert_path$key_name.pem"
        ssh $username@$ip_address -i $ec2_cert_path$key_name.pem
}

alias ec2-search=ec2search
alias ec2-connect=ec2connect
alias ec2-copy=ec2copy
