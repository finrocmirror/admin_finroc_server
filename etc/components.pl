our %config = (
    scm => {
        hg => {
            subdir => "hg",
            base_url => "https://YOURDOMAIN/hg"
        },
        svn => {
            subdir => "svn",
            base_url => "https://YOURDOMAIN/svn"
        }
    },
    scm_precedence => [ 'hg', 'svn' ],
    repositories => 'SCM_HOME/repositories',
    output => 'SCM_HOME/generated',
    distributions => {
        development => {
            dependency_sources => [ "http://YOURDOMAIN development main"],
            categories => {
                main => {
                    include => [
                        { name => 'make_builder' },
                        { name => 'finroc_.*' },
                        { name => 'rrlib_.*' }
                    ]
                }
            }
        },
        '13.10' => {
            dependency_sources => [ "http://YOURDOMAIN 13.10 main" ],
            categories => {
                main => {
                    include => [
                        { name => 'make_builder' },
                        { name => 'finroc_.*', branch => '13.10', license => 'finroc' },
                        { name => 'finroc_.*-java', branch => '13.10', license => 'gpl-2.0' },
                        { name => 'rrlib_.*', branch => '13.10', license => 'finroc' },
                        { name => 'rrlib.*-java', branch => '13.10', license => 'gpl-2.0' }
                    ]
                },
            },
        }
    }
);
