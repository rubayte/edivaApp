class Corelib
  
  def self
    
  end
  
  def self.uploadUserFile(userFile,user)
   
      valMsg = nil
      ## file name to do rest of the things after saving
      fl = userFile.original_filename
      ## save uploaded file 
      File.open(Rails.root.join('userspace',user,userFile.original_filename), 'w') do |file|
        file.write(userFile.read)
      end
      ## set return message      
      valMsg = "uploaded"
      return valMsg
      
  end

  
  def self.handleUserFileAndAction(userFile,user,action)
   
      valMsg = nil
   
      ## save uploaded file
      valMsg = uploadUserFile(userFile,user)
      
      if(valMsg == "uploaded")        
      
        if(action == "annotation" )
          ## annotate the uploaded vcf      
          valMsg = annotateVCF(fl,user)
        else
          ## rank the uploaded file      
          valMsg = rankUserAnnotatedFile(fl,user)
        end
      end 
        
      return valMsg
      
  end  


  def self.annotateVCF(userFile,user)
    
      valMsg = nil
      jobscript = ".jobtosubmit.sh"
      csv_file = ".csv_file.csv"
      
      usermail = User.getemail(user)
      mail = usermail.to_s[2..-3]

      ## write csv file
      File.open(Rails.root.join("userspace",user,csv_file), 'w') do |file|
        file.write(user + "," + mail + "\n")
      end
      
      ## delete the target file(s) if exists
      delcmmd = "rm userspace/" + user + "/" + jobscript
      system(delcmmd)
      
      ## call ediva-tools annotation program to calculate rank of the variants
      annCommand = "perl edivatools-code/Annotate/annotate.pl --input userspace/" + user + "/"+ userFile + 
      " -s complete -f --csv_file /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"

      ## write line to job file
      File.open(Rails.root.join("userspace",user,jobscript), 'w') do |file|
        file.write(annCommand + "\n")
      end
      

      ## chmod
      system ("chmod 775 userspace/" + user + "/" + jobscript)
      ## start the job
      system("userspace/"+ user +"/" + jobscript + " &")

      ## set return message
      valMsg = "annotated"
      
      return valMsg

  end
 
  def self.rankUserAnnotatedFile(userFile,user)

      valMsg = nil
      jobscript = ".jobtosubmit.sh"
      csv_file = ".csv_file.csv"

      usermail = User.getemail(user)
      mail = usermail.to_s[2..-3]

      ## write csv file
      File.open(Rails.root.join("userspace",user,csv_file), 'w') do |file|
        file.write(user + "," + mail + "\n")
      end

      ## delete the target file(s) if exists
      delcmmd = "rm userspace/" + user + "/" + jobscript
      system(delcmmd)

      ## if vcf file was provided then annotate it first
      if (userFile =~ /vcf$/)
        ## call ediva-tools annotation program to calculate rank of the variants
        annCommand = "perl edivatools-code/Annotate/annotate.pl --input userspace/" + user + "/"+ userFile + 
        " -s complete -f --csv_file /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"

        ## write line to job file
        File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
          file.write(annCommand + "\n")
        end
        
        ## update filename
        ## remove the .vcf extension from file name
        userFile = userFile[0..-5]
        userFile = userFile + ".sorted.annotated"

        ## call ediva-tools rank program to calculate rank of the variants
        rankCommand = "python edivatools-code/Prioritize/rankSNP.py --infile userspace/" + user + "/"+ userFile + 
        " --outfile userspace/"+ user + "/" + userFile + ".ranked  --csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"
        
        ## write line to job file
        File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
          file.write(rankCommand + "\n")
        end        
        
      else
        ## call ediva-tools rank program to calculate rank of the variants
        rankCommand = "python edivatools-code/Prioritize/rankSNP.py --infile userspace/" + user + "/"+ userFile + 
        " --outfile userspace/"+ user + "/" + userFile + ".ranked  --csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"
        
        ## write line to job file
        File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
          file.write(rankCommand + "\n")
        end        
      end

      
      ## chmod
      system ("chmod 775 userspace/" + user + "/" + jobscript)
      ## start the job
      system("userspace/"+ user +"/" + jobscript + " &")
      ## set return message
      valMsg = "ranked"

      return valMsg

  end    
  

  def self.familyActionsMerged(params,user)

    valMsg = nil
    
    mergedAnnotationFile = nil
    familyFile = 'family.txt'
    jobscript = ".jobtosubmit.sh"
    csv_file = ".csv_file.csv"
    
    usermail = User.getemail(user)
    mail = usermail.to_s[2..-3]

    ## write csv file
    File.open(Rails.root.join("userspace",user,csv_file), 'w') do |file|
       file.write(user + "," + mail + "\n")
    end
    
    ## delete the target file(s) if exists
    delcmmd = "rm userspace/" + user + "/" + familyFile
    system(delcmmd)
    delcmmd = "rm userspace/" + user + "/" + jobscript
    system(delcmmd)
    
    
    ## upload user file or select the file from userspace
    if (params[:vcfMerged])
      
      valMsg = uploadUserFile(params[:vcfMerged],user)

      if (valMsg == "uploaded")
        filename = params[:vcfMerged].original_filename
        commands = "" 
        ## write the family script
        params.each do |key,value| 
          if (key =~ /sample/)
            sampleindex = key[6..key.length]
            affectstatus = 1
            if (params[:"affected#{sampleindex}"] == nil)
              affectstatus = 0
            end
            File.open(Rails.root.join("userspace",user,familyFile), 'a') do |file|
              file.write(value + "\t" + affectstatus.to_s + "\n")
            end
          end
        end  
        
        if (filename =~ /vcf$/)
          ## call ediva-tools annotation program to calculate rank of the variants
          commands = "perl edivatools-code/Annotate/annotate.pl --input userspace/" + user + "/"+ filename + 
          " -s complete -f --csv_file /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"
          ## write line to job file
          File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
            file.write(commands + "\n")
          end
        
          ## update filename as per annotation tool
          ## remove the .vcf extension from file name
          filename = filename[0..-5]
        
          ## rank line
          commands = "python edivatools-code/Prioritize/rankSNP.py --infile userspace/" + user + "/"+ filename + ".sorted.annotated" +  
          " --outfile userspace/"+ user + "/" + filename + ".sorted.annotated.ranked  --csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"
          ## write line to job file
          File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
            file.write(commands + "\n")
          end
      
          ## family script
          if (params[:geneexclusionlist] == "1")
            commands = "python edivatools-code/Prioritize/familySNP.py --infile userspace/" + user + "/" + filename + ".sorted.annotated.ranked --outfile userspace/" +
            user + "/" + filename + ".sorted.annotated.ranked.analysed --filteredoutfile userspace/" + user + "/" + filename + ".sorted.annotated.ranked.analysed.filtered --family userspace/"+
            user + "/" + familyFile + " --inheritance " + params[:inheritenceType] + " --familytype " + params[:familyType] + " --geneexclusion edivatools-code/Resource/gene_exclusion_list.txt "+
            "--csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +"  > userspace/"+ user +"/.job.log 2>&1"
          else
            commands = "python edivatools-code/Prioritize/familySNP.py --infile userspace/" + user + "/" + filename + ".sorted.annotated.ranked --outfile userspace/" +
            user + "/" + filename + ".sorted.annotated.ranked.analysed --filteredoutfile userspace/" + user + "/" + filename + ".sorted.annotated.ranked.analysed.filtered --family userspace/"+
            user + "/" + familyFile + " --inheritance " + params[:inheritenceType] + " --familytype " + params[:familyType] + " --csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"   
          end
          ## write line to job file
          File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
            file.write(commands + "\n")
          end
        
        elsif( filename =~ /annotated$/)

          ## rank line
          commands = "python edivatools-code/Prioritize/rankSNP.py --infile userspace/" + user + "/"+ filename +   
          " --outfile userspace/"+ user + "/" + filename + ".ranked  --csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"
          ## write line to job file
          File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
            file.write(commands + "\n")
          end

          ## family script
          if (params[:geneexclusionlist] == "1")
            commands = "python edivatools-code/Prioritize/familySNP.py --infile userspace/" + user + "/" + filename + ".ranked --outfile userspace/" +
            user + "/" + filename + ".ranked.analysed --filteredoutfile userspace/" + user + "/" + filename + ".ranked.analysed.filtered --family userspace/"+
            user + "/" + familyFile + " --inheritance " + params[:inheritenceType] + " --familytype " + params[:familyType] + " --geneexclusion edivatools-code/Resource/gene_exclusion_list.txt "+
            "--csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +"  > userspace/"+ user +"/.job.log 2>&1"
          else
            commands = "python edivatools-code/Prioritize/familySNP.py --infile userspace/" + user + "/" + filename + ".ranked --outfile userspace/" +
            user + "/" + filename + ".ranked.analysed --filteredoutfile userspace/" + user + "/" + filename + ".ranked.analysed.filtered --family userspace/"+
            user + "/" + familyFile + " --inheritance " + params[:inheritenceType] + " --familytype " + params[:familyType] + " --csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"   
          end
          ## write line to job file
          File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
            file.write(commands + "\n")
          end
          
        elsif( filename =~ /ranked$/)
          
          ## family script
          if (params[:geneexclusionlist] == "1")
            commands = "python edivatools-code/Prioritize/familySNP.py --infile userspace/" + user + "/" + filename + " --outfile userspace/" +
            user + "/" + filename + ".analysed --filteredoutfile userspace/" + user + "/" + filename + ".analysed.filtered --family userspace/"+
            user + "/" + familyFile + " --inheritance " + params[:inheritenceType] + " --familytype " + params[:familyType] + " --geneexclusion edivatools-code/Resource/gene_exclusion_list.txt "+
            "--csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +"  > userspace/"+ user +"/.job.log 2>&1"
          else
            commands = "python edivatools-code/Prioritize/familySNP.py --infile userspace/" + user + "/" + filename + " --outfile userspace/" +
            user + "/" + filename + ".analysed --filteredoutfile userspace/" + user + "/" + filename + ".analysed.filtered --family userspace/"+
            user + "/" + familyFile + " --inheritance " + params[:inheritenceType] + " --familytype " + params[:familyType] + " --csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"   
          end
          ## write line to job file
          File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
            file.write(commands + "\n")
          end
          
        else
  
          valMsg = "Unknown file type provided in the analysis !"
          return valMsg

        end
          
        ## chmod
        system ("chmod 775 userspace/" + user +"/" + jobscript)
        ## start the job
        system("userspace/"+ user +"/" + jobscript + " &")
        ## set return message       
        valMsg = "jobsubmitted"
      end

    else
      mergedAnnotationFile = params[:selectedFileMerged]

       commands = "" 
       ## write the family script
       params.each do |key,value| 
         if (key =~ /sample/)
           sampleindex = key[6..key.length]
           affectstatus = 1
           if (params[:"affected#{sampleindex}"] == nil)
             affectstatus = 0
           end
           File.open(Rails.root.join("userspace",user,familyFile), 'a') do |file|
             file.write(value + "\t" + affectstatus.to_s + "\n")
           end
         end
       end  
        
       if (mergedAnnotationFile =~ /vcf$/)

        ## call ediva-tools annotation program to calculate rank of the variants
        commands = "perl edivatools-code/Annotate/annotate.pl --input userspace/" + user + "/"+ mergedAnnotationFile + 
        " -s complete -f --csv_file /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"
        ## write line to job file
        File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
          file.write(commands + "\n")
        end
        
        ## update filename as per annotation tool
        ## remove the .vcf extension from file name
        mergedAnnotationFile = mergedAnnotationFile[0..-5]
        mergedAnnotationFile = mergedAnnotationFile + ".sorted.annotated"

        ## rank line
        commands = "python edivatools-code/Prioritize/rankSNP.py --infile userspace/" + user + "/"+ mergedAnnotationFile +   
        " --outfile userspace/"+ user + "/" + mergedAnnotationFile + ".ranked  --csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"
        ## write line to job file
        File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
          file.write(commands + "\n")
        end         
        ## write line to job file
        File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
          file.write(commands + "\n")
        end         
    
        ## family script
        if (params[:geneexclusionlist] == "1")
          commands = "python edivatools-code/Prioritize/familySNP.py --infile userspace/" + user + "/" + mergedAnnotationFile + ".ranked --outfile userspace/" +
          user + "/" + mergedAnnotationFile + ".ranked.analysed --filteredoutfile userspace/" + user + "/" + mergedAnnotationFile + ".ranked.analysed.filtered --family userspace/"+
          user + "/" + familyFile + " --inheritance " + params[:inheritenceType] + " --familytype " + params[:familyType] + " --geneexclusion edivatools-code/Resource/gene_exclusion_list.txt "+
          "--csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"
        else
          commands = "python edivatools-code/Prioritize/familySNP.py --infile userspace/" + user + "/" + mergedAnnotationFile + ".ranked --outfile userspace/" +
          user + "/" + mergedAnnotationFile + ".ranked.analysed --filteredoutfile userspace/" + user + "/" + mergedAnnotationFile + ".ranked.analysed.filtered --family userspace/"+
          user + "/" + familyFile + " --inheritance " + params[:inheritenceType] + " --familytype " + params[:familyType]  + " --csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + 
          csv_file +" > userspace/"+ user +"/.job.log 2>&1"  
        end

        ## write line to job file
        File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
         file.write(commands + "\n")
        end

       elsif (mergedAnnotationFile =~ /annotated$/)

        ## rank line
        commands = "python edivatools-code/Prioritize/rankSNP.py --infile userspace/" + user + "/"+ mergedAnnotationFile +   
        " --outfile userspace/"+ user + "/" + mergedAnnotationFile + ".ranked  --csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"
        ## write line to job file
        File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
          file.write(commands + "\n")
        end         

        ## family script
        if (params[:geneexclusionlist] == "1")
          commands = "python edivatools-code/Prioritize/familySNP.py --infile userspace/" + user + "/" + mergedAnnotationFile + ".ranked --outfile userspace/" +
          user + "/" + mergedAnnotationFile + ".ranked.analysed --filteredoutfile userspace/" + user + "/" + mergedAnnotationFile + ".ranked.analysed.filtered --family userspace/"+
          user + "/" + familyFile + " --inheritance " + params[:inheritenceType] + " --familytype " + params[:familyType] + " --geneexclusion edivatools-code/Resource/gene_exclusion_list.txt "+
          "--csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"
        else
          commands = "python edivatools-code/Prioritize/familySNP.py --infile userspace/" + user + "/" + mergedAnnotationFile + ".ranked --outfile userspace/" +
          user + "/" + mergedAnnotationFile + ".ranked.analysed --filteredoutfile userspace/" + user + "/" + mergedAnnotationFile + ".ranked.analysed.filtered --family userspace/"+
          user + "/" + familyFile + " --inheritance " + params[:inheritenceType] + " --familytype " + params[:familyType]  + " --csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + 
          csv_file +" > userspace/"+ user +"/.job.log 2>&1"  
        end

        ## write line to job file
        File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
         file.write(commands + "\n")
        end

       elsif(mergedAnnotationFile =~ /ranked$/)
         
        ## family script
        if (params[:geneexclusionlist] == "1")
          commands = "python edivatools-code/Prioritize/familySNP.py --infile userspace/" + user + "/" + mergedAnnotationFile + " --outfile userspace/" +
          user + "/" + mergedAnnotationFile + ".analysed --filteredoutfile userspace/" + user + "/" + mergedAnnotationFile + ".analysed.filtered --family userspace/"+
          user + "/" + familyFile + " --inheritance " + params[:inheritenceType] + " --familytype " + params[:familyType] + " --geneexclusion edivatools-code/Resource/gene_exclusion_list.txt " +
          " --csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +" > userspace/"+ user +"/.job.log 2>&1"
        else
          commands = "python edivatools-code/Prioritize/familySNP.py --infile userspace/" + user + "/" + mergedAnnotationFile + " --outfile userspace/" +
          user + "/" + mergedAnnotationFile + ".analysed --filteredoutfile userspace/" + user + "/" + mergedAnnotationFile + ".analysed.filtered --family userspace/"+
          user + "/" + familyFile + " --inheritance " + params[:inheritenceType] + " --familytype " + params[:familyType]  + " --csvfile /var/www/html/ediva/current/userspace/"+ user + "/" + csv_file +
          " > userspace/"+ user +"/.job.log 2>&1"  
        end

        ## write line to job file
        File.open(Rails.root.join("userspace",user,jobscript), 'a') do |file|
         file.write(commands + "\n")
        end
       
       else

        valMsg = "Unknown file type provided in the analysis !"
        return valMsg

       end        
       
       ## chmod
       system ("chmod 775 userspace/" + user +"/" + jobscript)
       ## start the job
       system("userspace/"+ user +"/" + jobscript + " &")
       ## set return message       
       valMsg = "jobsubmitted"
    end     


    return valMsg

  end
  

  def self.familyActionsSeparate(sample1,sample2,sample3,vcf1,vcf2,vcf3,familyType,selectedFile1,selectedFile2,selectedFile3,affected1,affected2,affected3,inheritenceType,user,project)
  
    valMsg = nil
    
    if (vcf1 != nil and vcf2 != nil and vcf3 != nil)  
      ## upload VCFs
      vcfFileChecker = vcf1.original_filename
      
      valMsg = handleUserFile(vcf1,user,project)
      valMsg = handleUserFile(vcf2,user,project)
      valMsg = handleUserFile(vcf3,user,project)      
      
      mergedAnnotationFile = nil
      rankedFile = nil
      ## write the initial family file for the family script from oliver      
      familyFile = 'family.txt'
      ## handle affected nil parameters
      if (affected1 == nil)
        affected1 = 0
      end
      if (affected2 == nil)
        affected2 = 0
      end
      if (affected3 == nil)
        affected3 = 0
      end

      File.open(Rails.root.join(user,project,familyFile), 'w') do |file|
        file.write(sample1 + "\t" + affected1.to_s + "\n")
        file.write(sample2 + "\t" + affected2.to_s + "\n")
        file.write(sample3 + "\t" + affected3.to_s + "\n")
      end
      
      ## merge sample annotated files for ranking tool
      if (vcfFileChecker =~ /CD(.*)/)
        mergedAnnotationFile = 'CD_.GATK.snp.filtered.cleaned.vcf.annotated'
        rankedFile = 'CD_.GATK.snp.filtered.cleaned.vcf.annotated.ranked'
        annCommand = "scp /home/rrahman/Template/CDs/CD_.GATK.snp.filtered.cleaned.vcf.annotated /var/www/html/ediva/current/"+ user+ "/"+ project+ "/"
        system(annCommand)      
      elsif(vcfFileChecker =~ /VH(.*)/)
        mergedAnnotationFile = 'VH_.GATK.snp.filtered.cleaned.vcf.annotated'
        rankedFile = 'VH_.GATK.snp.filtered.cleaned.vcf.annotated.ranked'                
        annCommand = "scp /home/rrahman/Template/VHs/VH_.GATK.snp.filtered.cleaned.vcf.annotated /var/www/html/ediva/current/"+ user+ "/"+ project+ "/"
        system(annCommand)
      else
        ## lol you are fucked for now  
      end

      ##call ranking tool from oliver 
      valMsg = rankUserAnnotatedFile(mergedAnnotationFile,user,project)      
      sleep 30
      valMsg = runFamilyAnalysisTool(rankedFile,user,project,familyFile,inheritenceType)
      valMsg = "analysis"    
      return valMsg
  
    elsif(selectedFile1 != nil and selectedFile2 != nil and selectedFile3 != nil)
      
      mergedAnnotationFile = nil
      rankedFile = nil
      ## write the initial family file for the family script from oliver      
      familyFile = 'family.txt'
      ## handle affected nil parameters
      if (affected1 == nil)
        affected1 = 0
      end
      if (affected2 == nil)
        affected2 = 0
      end
      if (affected3 == nil)
        affected3 = 0
      end

      File.open(Rails.root.join(user,project,familyFile), 'w') do |file|
        file.write(sample1 + "\t" + affected1.to_s + "\n")
        file.write(sample2 + "\t" + affected2.to_s + "\n")
        file.write(sample3 + "\t" + affected3.to_s + "\n")
      end
      
      ## merge sample annotated files for ranking tool
      if (selectedFile1 =~ /CD(.*)/)
        mergedAnnotationFile = 'CD_.GATK.snp.filtered.cleaned.vcf.annotated'
        rankedFile = 'CD_.GATK.snp.filtered.cleaned.vcf.annotated.ranked'
        annCommand = "scp /home/rrahman/Template/CDs/CD_.GATK.snp.filtered.cleaned.vcf.annotated /var/www/html/ediva/current/"+ user+ "/"+ project+ "/"
        system(annCommand)      
      elsif(selectedFile1 =~ /VH(.*)/)
        mergedAnnotationFile = 'VH_.GATK.snp.filtered.cleaned.vcf.annotated'
        rankedFile = 'VH_.GATK.snp.filtered.cleaned.vcf.annotated.ranked'                
        annCommand = "scp /home/rrahman/Template/VHs/VH_.GATK.snp.filtered.cleaned.vcf.annotated /var/www/html/ediva/current/"+ user+ "/"+ project+ "/"
        system(annCommand)
      else
        ## lol you are fucked for now  
      end

      ##call ranking tool from oliver 
      valMsg = rankUserAnnotatedFile(mergedAnnotationFile,user,project)
      
      sleep 15
      #while(true)
        ## call family analysis tool from oliver
       # if FileTest.exists?(Rails.root + "/"+ uset+"/"+project+"/"+rankedFile)
      valMsg = runFamilyAnalysisTool(rankedFile,user,project,familyFile,inheritenceType)
        #  break
        #end
      #end
      valMsg = "analysis"    
    else    
      valMsg = "Your file selection is not appropriate ! Please carefully choose again !!"
    end
    
    return valMsg
  end
  
  def self.runFamilyAnalysisTool(rankedFile,user,project,familyFile,inhT)
    annCommand = "nohup python /home/rrahman/soft/eDiVaAnnotation/familySNP.py --infile /var/www/html/ediva/current/"+ user+ "/"+ project+ "/" + rankedFile + " --outfile /var/www/html/ediva/current/" +user+ "/"+ project+ "/" + rankedFile + "."+ inhT +".analyzed --filteredoutfile /var/www/html/ediva/current/" +user+ "/"+ project+ "/" + rankedFile + "."+ inhT +".analyzed.filtered --family /var/www/html/ediva/current/"+user+ "/"+ project+ "/family.txt --inheritance " + inhT + " &" 
    system(annCommand)          
    return annCommand
  end
  
   
end