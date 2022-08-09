#!/bin/bash 

injectFileToProductU2() {
    filenameWithExt=$(basename "$filepath")
    fileExtension="${filenameWithExt##*.}"
    filename="${filename%.*}"
    if [[ $fileExtension == "jar" ]] ; then
        cd "$pluginFolderPath"
        echo "CDed into : "
        pwd
        fileCount=$(ls -dq $packageName* | wc -l)
        if [[ $fileCount > 1 ]] ; then 
            echo "Found more than one match for the given file name. "
            echo "Do you want to delete all the matches in the plugins directory? It will delete $fileCount files."
            echo "Y/n"
            read  decision
            if ! [[ $decision == "Y" ]] ; then 
                echo "Halting the operation..."
                exit 1;
            fi
        fi
        if [[ $fileCount == 0 ]] ; then 
            echo "Could not find any files with that name in plugins folder. Do you want to continue Y/n?"
            read  decision
            if ! [[ $decision == "Y" ]] ; then 
                echo "Halting the operation..."
                exit 1;
            fi
        fi
        if ! [[ $fileCount == 0 ]] ; then
            echo "Removing : $packageName* files"
            rm $packageName*
        fi
        cd -
        echo "CDed into : "
        pwd

        cd "$dropinsFolderPath"
        echo "CDed into : "
        pwd
        fileCount=$(ls -dq $packageName* | wc -l)
        if [[ $fileCount > 1 ]] ; then 
            echo "Found more than one match for the given file name. "
            echo "Do you want to delete all the matches in the Dropins directory? It will delete $fileCount files.";
            echo "Y/n"
            read  decision
            if ! [[ $decision == "Y" ]] ; then 
                echo "Halting the operation..."
                exit 1;
            fi
        fi

        if ! [[ $fileCount == 0 ]] ; then
            echo "Removing : $packageName* files"
            rm $packageName*
        fi

        echo "Coping $filepath into the current directory."
        cp $filepath .
        cd -
        echo "CDed into : "
        pwd
    fi
}

injectFileToProductWUM() {
    injectFileToProductU2
}

reldir=`dirname $0`
cd $reldir

createNewPack=0

while [ True ]; do
if [ "$1" = "--tool" -o "$1" = "-t" ]; then
    tool=$2
    shift 2
elif [ "$1" = "--product" -o "$1" = "-p" ]; then
    updateProduct=$2
    shift 2
elif [ "$1" = "--version" -o "$1" = "-v" ]; then
    updateVersion=$2
    shift 2
elif [ "$1" = "--caseId" -o "$1" = "-c" ]; then
    caseId=$2
    shift 2
elif [ "$1" = "--env" -o "$1" = "-e" ]; then
    env=$2
    shift 2
elif [ "$1" = "--inject" -o "$1" = "-i" ]; then
    filepath=$2
    shift 2
elif [ "$1" = "--package" -o "$1" = "-pn" ]; then
    packageName=$2
    shift 2
elif [ "$1" = "--new" -o "$1" = "-n" ]; then
    createNewPack=1
    shift 1
elif [ "$1" = "--start" ]; then
    startPack=1
    shift 1
elif [ "$1" = "--debug" ]; then
    debugPack=1
    shift 1
else
    break
fi
done

if ! [[ $tool && $updateProduct && $updateVersion && $caseId ]] ; then
    echo "--tool, --product, --version, --caseId arguments are mendatory. Please provide."
    exit 1;
fi

if [[ $filepath ]] ; then 
    if ! [[ $packageName ]] ; then 
        echo "Please provide package name if you want to inject the file. For example if the path is '/home/com.fasterxml.jackson.dataformat.jackson-dataformat-cbor-2.13.2.jar' package name is 'com.fasterxml.jackson.dataformat.jackson-dataformat-cbor'"
    fi
fi



productBasePath="$tool/$updateProduct/$updateVersion"
currentExtractionPath="$productBasePath/target/$caseId"
extractedFolderName="$updateProduct-$updateVersion"
productIdentifierWum="$updateProduct-$updateVersion"
extractedProductBasePath="$currentExtractionPath/$extractedFolderName"
pluginFolderRelativePath="repository/components/plugins"
dropinsFolderRelativePath="repository/components/dropins"
pluginFolderPath="$extractedProductBasePath/$pluginFolderRelativePath"
dropinsFolderPath="$extractedProductBasePath/$dropinsFolderRelativePath"
binFolder="$extractedProductBasePath/bin"
startupShFile="$binFolder/wso2server.sh"
wso2WumFolder="~/.wum3"
wso2WumConfigFilePath="$wso2WumFolder/config.yaml"
wso2WumProductFullPath="$wso2WumFolder/products/$updateProduct/$updateVersion/full"

if [ $createNewPack == 1 ] ; then
    rm -rf "$currentExtractionPath/"
    mkdir -p "$currentExtractionPath/"
    if [[ "$tool" == "u2" ]] ; then 
        fileCount=$(ls -dq $productBasePath/$updateProduct-$updateVersion* | wc -l)
        if [[ $fileCount == 0 ]] ; then
            echo "Please copy paste the base pack to this location : $productBasePath/ and type Y and enter to continue."
            read decision
            if ! [[ $decision == "Y" ]] ; then
                echo "Halting the process..."
                exit 1;
            fi
        fi
        unzip "$productBasePath/$updateProduct-$updateVersion*" -d "$currentExtractionPath/"
    fi
    if [[ "$tool" == "wum" ]] ; then 
        wum add $productIdentifierWum
        rm -rf "$wso2WumProductFullPath"
    fi
fi

if [[ $filepath ]] ; then
    if [[ $createNewPack == 0 ]] ; then
        if [[ "$tool" == "u2" ]] ; then
            injectFileToProductU2
        fi
        if [[ "$tool" == "wum" ]] ; then
            injectFileToProductWUM
        fi
        if ! [[ $startPack || $debugPack ]] ; then
            exit 0
        fi
    fi
fi

if [[ "$tool" == "u2" && $createNewPack == 1 ]]; then
    echo "u2" 
    echo 
    echo
    echo
    echo  Email: 
    read  email
    echo -n Password: 
    read -s password

    chmod +x "$extractedProductBasePath/bin/wso2update_linux"
    ./updateu2phase1.exp "$extractedProductBasePath" "$password" "$email"
    echo "================================================="
    echo "================================================="
    echo "================================================="
    echo "First update"
    echo "================================================="
    echo "================================================="
    echo "================================================="
    cat "$extractedProductBasePath/updates/config.json" > test.json
    jq --argfile file staging.json '.services.staging = $file' test.json > "$extractedProductBasePath/updates/config.json"
    cat "$extractedProductBasePath/updates/config.json" > test.json
    jq --argfile file uat.json '.services.uat = $file' test.json > "$extractedProductBasePath/updates/config.json"
    cat "$extractedProductBasePath/updates/config.json" > test.json
    ./updateu2phase2.exp "$extractedProductBasePath" "$password"
    cat "$extractedProductBasePath/updates/config.json" > test.json
    echo "================================================="
    echo "================================================="
    echo "================================================="
    echo "Updated with wso2"
    echo "================================================="
    echo "================================================="
    echo "================================================="
    if [ "$env" == "staging" ]; then
        jq '.services.staging.enabled = true | .services.wso2.enabled = false' test.json > "$extractedProductBasePath/updates/config.json"
        ./updateu2phase2.exp "$extractedProductBasePath" "$password"
        echo "================================================="
        echo "================================================="
        echo "================================================="
        echo "Updated with staging"
        echo "================================================="
        echo "================================================="
        echo "================================================="
    fi
    if [ "$env" == "uat" ]; then
        jq '.services.uat.enabled = true | .services.wso2.enabled = false' test.json > "$extractedProductBasePath/updates/config.json"
        ./updateu2phase2.exp "$extractedProductBasePath" "$password"
        echo "================================================="
        echo "================================================="
        echo "================================================="
        echo "Updated with uat"
        echo "================================================="
        echo "================================================="
        echo "================================================="
    fi

    if [[ $filepath ]] ; then
        injectFileToProductU2
    fi
    # rm test.json
elif [[ "$tool" == "wum" && $createNewPack == 1 ]] ; then
    echo "wum"
    if [ "$env" == "staging" ]; then
        yq e -i '.repositories.staging.enabled = true' $wso2WumConfigFilePath
        yq e -i '.repositories.wso2.enabled = false' $wso2WumConfigFilePath
        yq e -i '.repositories.uat.enabled = false' $wso2WumConfigFilePath
        wum update $productIdentifierWum
        unzip "$wso2WumProductFullPath/*.zip" -d "$currentExtractionPath/"
    fi
    if [ "$env" == "wso2" ]; then
        yq e -i '.repositories.staging.enabled = false' $wso2WumConfigFilePath
        yq e -i '.repositories.wso2.enabled = true' $wso2WumConfigFilePath
        yq e -i '.repositories.uat.enabled = false' $wso2WumConfigFilePath
        wum update $productIdentifierWum
        unzip "$wso2WumProductFullPath/*.zip" -d "$currentExtractionPath/"
    fi
    if [[ $filepath ]] ; then
        injectFileToProductWUM
    fi
   
fi

if [[ $startPack || $debugPack ]] ; then
    if [[ $startPack ]] ; then
        sh $startupShFile 
    elif [[ $debugPack ]] ; then
        sh $startupShFile -debug 5005
    fi
fi

echo "The end"