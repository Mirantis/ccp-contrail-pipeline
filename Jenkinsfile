/**
 *
 * contrail build, test, promote pipeline
 *
 * Expected parameters:
 *   ARTIFACTORY_URL        Artifactory server location
 *   ARTIFACTORY_OUT_REPO   local repository name to upload image
 *   ARTIFACTORY_SERVER_NAME  artifactory server to use (configuration of
 *                              artifactory plugin)
 *   DOCKER_REGISTRY_SERVER Docker server to use to push image
 *   DOCKER_REGISTRY_SSL    Docker registry is SSL-enabled if true
 *   OS                     distribution name to build for (debian, ubuntu, etc.)
 *   DIST                   distribution version (jessie, trusty)
 *   ARCH                   comma-separated list of architectures to build
 *   FORCE_BUILD            Force build even when image exists
 *   BUILD_DPDK             Build dpdk-enabled vrouter
 *   DPDK_VERSION           DPDK version to fetch
 *   PROMOTE_ENV            Environment for promotion (default "stable")
 *   KEEP_REPOS             Always keep input repositories even on failure
 *   SOURCE_URL             URL to source code base (component names will be
 *                          appended)
 *   SOURCE_BRANCH          Branch of opencontrail to build
 *   SOURCE_CREDENTIALS     Credentials to use to checkout source
 *   PIPELINE_LIBS_URL      URL to git repo with shared pipeline libs
 *   PIPELINE_LIBS_BRANCH   Branch of pipeline libs repo
 *   PIPELINE_LIBS_CREDENTIALS_ID   Credentials ID to use to access shared
 *                                  libs repo
 */

// Load shared libs
def common, artifactory
fileLoader.withGit(PIPELINE_LIBS_URL, PIPELINE_LIBS_BRANCH, PIPELINE_LIBS_CREDENTIALS_ID, '') {
    common = fileLoader.load("common");
    artifactory = fileLoader.load("artifactory");
}

// Define global variables
def timestamp = common.getDatetime()

def components = [
    ["contrail-build", "tools/build", SOURCE_BRANCH],
    ["contrail-controller", "controller", SOURCE_BRANCH],
    ["contrail-vrouter", "vrouter", SOURCE_BRANCH],
    ["contrail-third-party", "third_party", SOURCE_BRANCH],
    ["contrail-generateDS", "tools/generateds", SOURCE_BRANCH],
    ["contrail-sandesh", "tools/sandesh", SOURCE_BRANCH],
    ["contrail-packages", "tools/packages", SOURCE_BRANCH],
    ["contrail-nova-vif-driver", "openstack/nova_contrail_vif", SOURCE_BRANCH],
    ["contrail-neutron-plugin", "openstack/neutron_plugin", SOURCE_BRANCH],
    ["contrail-nova-extensions", "openstack/nova_extensions", SOURCE_BRANCH],
    ["contrail-heat", "openstack/contrail-heat", SOURCE_BRANCH],
    ["contrail-ceilometer-plugin", "openstack/ceilometer_plugin", "master"],
    ["contrail-web-storage", "contrail-web-storage", SOURCE_BRANCH],
    ["contrail-web-server-manager", "contrail-web-server-manager", SOURCE_BRANCH],
    ["contrail-web-controller", "contrail-web-controller", SOURCE_BRANCH],
    ["contrail-web-core", "contrail-web-core", SOURCE_BRANCH],
    ["contrail-webui-third-party", "contrail-webui-third-party", SOURCE_BRANCH]
]

def sourcePackages = [
    "contrail-web-core",
    "contrail-web-controller",
    "contrail",
    "ifmap-server",
    "neutron-plugin-contrail",
    "ceilometer-plugin-contrail",
    "contrail-heat"
]

def inRepos = [
    "generic": [
        "in-dockerhub"
    ],
    "debian": [
        "in-debian",
        "in-debian-security",
        "in-tcpcloud-apt"
    ],
    "ubuntu": [
        "in-ubuntu",
        "in-tcpcloud-apt"
    ]
]

def art = artifactory.connection(
    ARTIFACTORY_URL,
    DOCKER_REGISTRY_SERVER,
    DOCKER_REGISTRY_SSL ?: true,
    ARTIFACTORY_OUT_REPO,
    ARTIFACTORE_SERVER_NAME ?: "default"
)

def git_commit = [:]
def properties = [:]


def buildSourcePackageStep(img, pkg) {
    return {
        sh("rm -f src/build/packages/${pkg}_* || true")
        img.inside {
            sh("cd src; make -f packages.make source-package-${pkg}")
        }
    }
}

def buildBinaryPackageStep(img, pkg, opts = '-b') {
    return {
        img.inside {
            sh("test -d src/build/${pkg} && rm -rf src/build/${pkg} || true")
            sh("dpkg-source -x src/build/packages/${pkg}_*.dsc src/build/${pkg}")
            sh("cd src/build/${pkg}; sudo apt-get update; dpkg-checkbuilddeps 2>&1|cut -d : -f 3|sed 's,(.*),,g'|xargs sudo apt-get install -y")
            sh("cd src/build/${pkg}; debuild --no-lintian -uc -us ${opts}")
        }
    }
}

node('docker') {
    checkout scm
    git_commit['contrail-pipeline'] = common.getGitCommit()

    stage("checkout") {
        gitCheckoutSteps = [:]
        for (component in components) {
            gitCheckoutSteps[component[0]] = common.gitCheckoutStep(
                "src/${component[1]}",
                "${SOURCE_URL}/${component[0]}.git",
                component[2],
                SOURCE_CREDENTIALS,
                true,
                true
            )
        }
        parallel gitCheckoutSteps

        for (component in components) {
            dir("src/${component[1]}") {
                commit = common.getGitCommit()
                git_commit[component[0]] = commit
                properties["git_commit_"+component[0].replace('-', '_')] = commit
            }
        }

        sh("test -e src/SConstruct || ln -s tools/build/SConstruct src/SConstruct")
        sh("test -e src/packages.make || ln -s tools/packages/packages.make src/packages.make")
        sh("test -d src/build && rm -rf src/build || true")

        if (BUILD_DPDK.toBoolean() == true) {
            sh("wget --no-check-certificate -O - ${art.url}/in-dpdk/dpdk-${DPDK_VERSION}.tar.xz | tar xJf -; mv dpdk-* dpdk")
        }
    }

    // Check if image of this commit hash isn't already built
    def results = artifactory.findArtifactByProperties(
        art,
        properties,
        art.outRepo
    )
    if (results.size() > 0) {
        println "There are already ${results.size} artefacts with same git commits"
        if (FORCE_BUILD.toBoolean() == false) {
            common.abortBuild()
        }
    }

    stage("prepare") {
        // Prepare Artifactory repositories
        out = artifactory.createRepos(art, inRepos['generic']+inRepos[OS], timestamp)
        println "Created input repositories: ${out}"
    }

    try {
        def imgName = "${OS}-${DIST}-${ARCH}"
        def img
        stage("build-source") {
            docker.withRegistry("${art.docker.proto}://in-dockerhub-${timestamp}.${art.docker.base}", "artifactory") {
                // Hack to set custom docker registry for base image
                sh "git checkout -f docker/${imgName}.Dockerfile; sed -i -e 's,^FROM ,FROM in-dockerhub-${timestamp}.${art.docker.base}/,g' docker/${imgName}.Dockerfile"
                img = docker.build(
                    "${imgName}:${timestamp}",
                    [
                        "--build-arg artifactory_url=${art.url}",
                        "--build-arg timestamp=${timestamp}",
                        "-f docker/${imgName}.Dockerfile",
                        "docker"
                    ].join(' ')
                )
            }

            img.inside {
                sh("cd src/third_party; python fetch_packages.py")
                sh("cd src/contrail-webui-third-party; python fetch_packages.py -f packages.xml")
	        sh("rm -rf src/contrail-web-core/node_modules")
        	sh("mkdir src/contrail-web-core/node_modules")
	        sh("cp -rf src/contrail-webui-third-party/node_modules/* src/contrail-web-core/node_modules/")
            }

            buildSteps = [:]
            for (pkg in sourcePackages) {
                buildSteps[pkg] = buildSourcePackageStep(img, pkg)
            }
            //parallel buildSteps
            common.serial(buildSteps)
        }

        //for (arch in ARCH.split(',')) {
        stage("build-binary-${ARCH}") {
            buildSteps = [:]
            for (pkg in sourcePackages) {
                buildSteps[pkg] = buildBinaryPackageStep(img, pkg, '-b')
            }
            parallel buildSteps
        }
        //}
    } catch (Exception e) {
        currentBuild.result = 'FAILURE'
        if (KEEP_REPOS.toBoolean() == false) {
            println "Build failed, cleaning up input repositories"
            out = artifactory.deleteRepos(art, inRepos['generic']+inRepos[OS], timestamp)
            println "Cleaning up docker images"
            sh("docker images | grep -E '[-:\\ ]+${timestamp}[\\.\\ /\$]+' | awk '{print \$3}' | xargs docker rmi -f || true")
        }
        throw e
    }

    stage("upload") {
        buildSteps = [:]
        debFiles = sh script: "ls src/build/*.deb", returnStdout: true
        for (file in debFiles.tokenize()) {
            workspace = common.getWorkspace()
            def fh = new File("${workspace}/${file}".trim())
            buildSteps[fh.name.split('_')[0]] = artifactory.uploadPackageStep(
                art,
                fh.name,
                properties,
                DIST,
                'main',
                timestamp,
                fh.bytes
            )
        }
        parallel buildSteps
    }
}

def promoteEnv = PROMOTE_ENV ? PROMOTE_ENV : "stable"

timeout(time:1, unit:"DAYS") {
    input "Promote to ${promoteEnv}?"
}

node('docker') {
    stage("promote-${promoteEnv}") {
        // TODO: promote
    }
}
