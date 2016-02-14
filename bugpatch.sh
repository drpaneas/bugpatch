bug=$1

# TODO: against noarch
#       subversion-bash-completion.noarch
#       detect if packagekit running and exit asap
#       implement a loading bar while waiting...

# --- COLOR DEFINITIONS --- #
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
pink=$(tput setaf 5)
bold=$(tput bold)
under_1=$(tput smul)
under_0=$(tput rmul)
reset=$(tput sgr0)
# ------------------------ #

pgrep zypper 1> /dev/null
if [ $? -eq 0 ]; then
  echo "${red}ERROR -- Please kill zypper (PID=$(pgrep zypper)) first and then re-run this script${reset}"
  echo
  exit 1
fi


search_needed() {
  echo "${pink}#######################################################${reset}"
  echo "${pink}#${reset} ${green}Searching into not yet installed but needed patches${reset} ${pink}#${reset}"
  echo "${pink}#######################################################${reset}"

  # Search in all not installed but available (needed) patches
  for patch in $(zypper patches 2>/dev/null | tail -n +5 | grep '|[[:space:]]\+Needed' | awk -F '|' '{ print $2 }')
  do
      # If you found a patch with this bug number:
      zypper patch-info "$patch" | egrep "$bug" > /dev/null
      if [ $? -eq 0 ]
      then
        echo -e "\n  --> ${blue}Patch${reset} ${green}found:${reset} ${bold}'$patch'${reset}"
        echo

        # print generic info about the patch
        echo "${bold}$(zypper patches | grep Category)${reset}"
        echo "------------------------------------------------------------------------------------------------"
        zypper patches | grep "$patch"
        echo

        # Find which patch packages are installed in your system (if any)
        echo
        echo "${bold}Vulnerable packages in your system:${reset}"
        echo "-----------------------------------"

        # Search if each pkg is installed
        for pkg in $(zypper patch-info "$patch" | sed -n '/Conflicts/,/END/p' | grep -v 'Conflicts' | grep -v 'srcpackage' | sed -e 's/^[[:space:]]*//' | grep -v 'i586' | awk -F '<' '{print $1}' | sed -e 's/.x[0-9]*_[0-9]*/ /')
        do
          rpm -q "$pkg" > /dev/null
          if [ $? -eq 0 ]
          then
            echo -e "$(rpm -q "$pkg" | sed -e 's/.x[0-9]*_[0-9]*/ /')\t${red}[installed]${reset}"
          else
            echo -e "$pkg\t${yellow}[not installed]${reset}"  # pkg not installed, doesn't mean you're OK -- unless ALL of these pkgs are 'not installed'
          fi
        done

        # Print the fixed version of the pkgs that come along with the patch
        echo
        echo "${bold}Patch provides the following fixed packages:${reset}"
        echo "---------------------------------------------"
        zypper patch-info "$patch" | sed -n '/Conflicts/,/END/p' | grep -v 'Conflicts' | grep -v 'srcpackage' | sed -e 's/^[[:space:]]*//' | grep -v 'i586' | sed -e 's/.x[0-9]*_[0-9]*\ < /-/'
        echo

        echo "${bold}System status:${reset}"
        echo "--------------"
        echo "${red}Affected${reset}"
        echo
        echo "${bold}How to fix it:${reset}"
        echo "--------------"
        echo "Type:  ${green}zypper install -t patch $patch ${reset}"

        result=0    # If you found it, stop searching. Exit with 0 code.
        break

      else
        result=1
      fi
  done

  check_if_zero=$(zypper patches 2>/dev/null | tail -n +5 | grep '|[[:space:]]\+Needed' | awk -F '|' '{ print $2 }' | wc -l)
  if [[ "$check_if_zero" -eq 0 ]]; then
    result=1
  fi

  if [ "$result" -eq 1 ]; then
    echo -e "\n  --> ${blue}Patch${reset} ${red}not found${reset}\n\n"
  fi

  return $result
}


# ----------------------------------------------------------------------------------------------------------------------------------

search_not_needed() {
  echo "${pink}############################################################${reset}"
  echo "${pink}#${reset} ${green}Searching into not yet installed and unecessarry patches${reset} ${pink}#${reset}"
  echo "${pink}############################################################${reset}"


  # Search in all not installed but available (not needed) patches
  for patch in $(zypper patches 2>/dev/null | tail -n +5 | grep '|[[:space:]]\+Not Needed' | awk -F '|' '{ print $2 }')
  do
      # If you found a patch with this bug number:
      zypper patch-info "$patch" | egrep "$bug" > /dev/null
      if [ $? -eq 0 ]
      then
        echo -e "\n  --> ${blue}Patch${reset} ${green}found:${reset} ${bold}'$patch'${reset}"
        echo

        # print generic info about the patch
        echo "${bold}$(zypper patches | grep Category)${reset}"
        echo "------------------------------------------------------------------------------------------------"
        zypper patches | grep "$patch"
        echo

        # Find which patch packages are installed in your system (if any)
        echo
        echo "${bold}Vulnerable packages in your system:${reset}"
        echo "-----------------------------------"

        # Search if each pkg is installed
        for pkg in $(zypper patch-info "$patch" | sed -n '/Conflicts/,/END/p' | grep -v 'Conflicts' | grep -v 'srcpackage' | sed -e 's/^[[:space:]]*//' | grep -v 'i586' | awk -F '<' '{print $1}' | sed -e 's/.x[0-9]*_[0-9]*/ /')
        do
          rpm -q "$pkg" > /dev/null
          if [ $? -eq 0 ]
          then
            echo -e "$(rpm -q "$pkg" | sed -e 's/.x[0-9]*_[0-9]*/ /')\t${red}[installed]${reset}"
          else
            echo -e "$pkg\t${yellow}[not installed]${reset}"  # pkg not installed, doesn't mean you're OK -- unless ALL of these pkgs are 'not installed'
          fi
        done

        # Print the fixed version of the pkgs that come along with the patch
        echo
        echo "${bold}Patch provides the following fixed packages:${reset}"
        echo "---------------------------------------------"
        zypper patch-info "$patch" | sed -n '/Conflicts/,/END/p' | grep -v 'Conflicts' | grep -v 'srcpackage' | sed -e 's/^[[:space:]]*//' | grep -v 'i586' | sed -e 's/.x[0-9]*_[0-9]*\ < /-/'
        echo

        echo "${bold}System status:${reset}"
        echo "--------------"
        echo "${yellow}Not Affected${reset}"
        echo
        echo "${bold}How to fix it:${reset}"
        echo "--------------"
        echo "${green}Not needed${reset}"

        result=0    # If you found it, stop searching. Exit with 0 code.
        break

      else
        result=1
      fi
  done

  if [ "$result" -eq 1 ]; then
    echo -e "\n  --> ${blue}Patch${reset} ${red}not found${reset}\n\n"
  fi

  return $result
}


# ----------------------------------------------------------------------------------------------------- #

search_installed () {
  echo "${pink}####################################${reset}"
  echo "${pink}#${reset} ${green}Searching into installed patches${reset} ${pink}#${reset}"
  echo "${pink}####################################${reset}"

  # Search into Installed Patches using zypper patches command to get the name of the patch
  for patch in $(zypper patches 2>/dev/null | grep '|[[:space:]]\+Installed' | awk -F '|' '{ print $2 }')
  do
      zypper patch-info "$patch" | egrep "$bug" > /dev/null   # Check if patch is installed
      if [ $? -eq 0 ]
      then

          # Yeap, it's installed
          echo "${bold}System status:${reset} ${green}Safe ${reset}- Your system is patched against ${red}#$bug${reset} bug"
          echo
          echo "${bold}Patch name:${reset} ${green}$patch ${reset}"
          echo
          echo "${bold}Patch includes the following packages:${reset}"
          echo      "--------------------------------------"

          # Find the pkgs related to this patch
          for pkg in $(zypper patch-info "$patch" | sed -n '/Conflicts/,/END/p' | grep -v 'Conflicts' | grep -v 'srcpackage' | sed -e 's/^[[:space:]]*//' | grep -v 'i586' | sed -e 's/.x[0-9]*_[0-9]*\ < /-/')
          do
              # Chech if each of these pkgs is installed
              rpm -q "$pkg" > /dev/null
              if [ $? -eq 0 ]
              then
                  echo -e "$(rpm -q "$pkg" | sed -e 's/.x[0-9]*_[0-9]*/ /')\t${green}[installed]${reset}"
              else
                  echo -e "$pkg\t${yellow}[not installed]${reset}"
              fi
          done

          # Enumerate the full list of pkgs related to this patch along with their versions
          echo
          echo "${bold}Fixed (patched) packages installed:${reset}"
          result=0
          echo      "-----------------------------------"
          for pkg in $(zypper patch-info "$patch" | sed -n '/Conflicts/,/END/p' | grep -v 'Conflicts' | grep -v 'srcpackage' | sed -e 's/^[[:space:]]*//' | grep -v 'i586' | awk -F '<' '{print $1}' | sed -e 's/.x[0-9]*_[0-9]*/ /')
          do
            # Check if we have the exact patched version installed
            rpm -q "$pkg" > /dev/null
            if [ $? -eq 0 ]
            then
              echo "${green}$(rpm -q "$pkg" | sed -e 's/.x[0-9]*_[0-9]*/ /')${reset}"
            fi
          done

          # Needed for those who want to go back and forth, testing and reproducing the bug
          echo
          echo "${bold}How to Downgrade (for whatever reason)${reset}"
          echo "--------------------------------------"
          for pkg in $(zypper patch-info "$patch" | sed -n '/Conflicts/,/END/p' | grep -v 'Conflicts' | grep -v 'srcpackage' | sed -e 's/^[[:space:]]*//' | grep -v 'i586' | awk -F '<' '{print $1}' | sed -e 's/.x[0-9]*_[0-9]*/ /')
          do
            rpm -q "$pkg" > /dev/null # if it's installed

            if [ $? -eq 0 ]
            then
                    # Find the previous version of the pkg
                    previous_pkg=$(zypper se -s "$pkg" | grep 'v ' | head -1 | awk -F '|' '{print $2 $4}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -s ' ' | sed -e 's/\s/-/g' )
                    echo "Type: ${green}zypper in --oldpackage $previous_pkg${reset}"
            fi
          done

          result=0
          break

    else
          result=1
    fi

  done

  if [ "$result" -eq 1 ]; then
    echo -e "\n  --> ${blue}Patch${reset} ${red}not found${reset}\n\n"
  fi

  return $result
}


# =============================== #

number_installed=$(zypper patches 2>/dev/null | grep '|[[:space:]]\+Installed' | awk -F '|' '{ print $2 }' | wc -l)
number_not_needed=$(zypper patches 2>/dev/null | tail -n +5 | grep '|[[:space:]]\+Not Needed' | awk -F '|' '{ print $2 }' | wc -l)
number_needed=$(zypper lp 2>/dev/null | tail -n +6 | awk -F '|' '{ print $2 }' | wc -l)


echo "Searching for patches in ${under_1}Optimized order${under_0}:"

if [ "$number_needed" -lt "$number_not_needed" ]; then
  if [ "$number_needed" -lt "$number_installed" ]; then
    echo "1. Needed ($number_needed)"
    if [ "$number_not_needed" -lt "$number_installed" ]; then
      echo "2. Not Needed ($number_not_needed)"
      echo "3. Installed ($number_installed)"
    else
      echo "2. Installed ($number_installed)"
      echo "3. Not Needed ($number_not_needed)"
    fi
  else
    echo "1. Installed ($number_installed)"
    echo "2. Needed ($number_needed)"
    echo "3. Not Needed ($number_not_needed)"
  fi
else
  if [ "$number_not_needed" -lt "$number_installed" ]; then
    echo "1. Not Needed ($number_not_needed)"
    if [ "$number_installed" -lt "$number_needed" ]; then
      echo "2. Installed ($number_installed)"
      echo "3. Needed ($number_needed)"
    else
      echo "2. Needed ($number_needed)"
      echo "3. Installed ($number_installed)"
    fi
  else
    echo "1. Installed ($number_installed)"
    echo "2. Not Needed ($number_not_needed)"
    echo "3. Needed ($number_needed)"
  fi
fi

echo

exitstatus () {
  if [ $? -eq 1 ]; then
    echo -e "\n ${yellow}===>${reset}  Seems like ${red}$bug${reset} bug is ${red}not${reset} yet ${red}fixed${reset} for $(lsb-release -d | awk -F ':[[:space:]]' '{ print $2 }') ${yellow}<===${reset}\n\n"
    exit 1
  else
    exit 0
  fi
}

tmpstatus () {
  if [ $? -eq 0 ]; then
    exit 0
  fi
}


if [ "$number_needed" -lt "$number_not_needed" ]; then
  if [ "$number_needed" -lt "$number_installed" ]; then
    search_needed
    tmpstatus
    if [ "$number_not_needed" -lt "$number_installed" ]; then
      search_not_needed
      tmpstatus
      search_installed
      exitstatus
    else
      search_installed
      tmpstatus
      search_not_needed
      exitstatus
    fi
  else
    search_installed
    tmpstatus
    search_needed
    tmpstatus
    search_not_needed
      exitstatus
  fi
else
  if [ "$number_not_needed" -lt "$number_installed" ]; then
    search_not_needed
    tmpstatus
    if [ "$number_installed" -lt "$number_needed" ]; then
      search_installed
      tmpstatus
      search_needed
      tmpstatus
      exitstatus
    else
      search_needed
      tmpstatus
      search_installed
      tmpstatus
      exitstatus
    fi
  else
    search_installed
    tmpstatus
    search_not_needed
    tmpstatus
    search_needed
    exitstatus
  fi
fi



