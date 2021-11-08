run_ssh_agent() {
    ssh-agent -s > ~/.ssh/.agent 2>/dev/null
    . ~/.ssh/.agent >/dev/null
}

source_ssh_agent() {
    agent_count="$(pgrep -c ssh-agent)"

    if [ "$agent_count" -eq "0" ]; then
        # start the agent
        printf -- "INFO: starting ssh-agent\n"
        run_ssh_agent
    elif [ "$agent_count" -gt "1" ]; then
        # too many agents
        echo "WARN: ${agent_count} ssh-agents found"
        killall ssh-agent 2>/dev/null
        run_ssh_agent
    elif [ "$agent_count" -eq "1" ]; then
        # source the running agent
        . ~/.ssh/.agent >/dev/null
    fi

    if ! agent_pid=$(
       pgrep ssh-agent
    ); then
        echo "ERROR: ssh-agent: not running"
    fi

    if [ "$SSH_AGENT_PID" -ne "$agent_pid" ]; then
        printf -- "WARN: SSH_AGENT_PID %s != %s\n" \
            $SSH_AGENT_PID $agent_pid
        killall ssh-agent
        run_ssh_agent
    fi
}
