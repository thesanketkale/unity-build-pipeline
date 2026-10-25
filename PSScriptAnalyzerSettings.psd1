@{
    # Severity of issues to report
    Severity = @('Error', 'Warning')

    # Rules to include
    IncludeRules = @(
        'PSAvoidDefaultValueSwitchParameter',
        'PSAvoidNullOrEmptyHelpMessageAttribute',
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingPositionalParameters',
        'PSCheckShouldProcess',
        'PSReservedCmdletChar',
        'PSReservedParams',
        'PSUseApprovedVerbs',
        'PSUseCmdletCorrectly',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUseSingularNouns'
    )

    # Rules to exclude where specialized batchmode or runner tooling requires custom design
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
    )
}
