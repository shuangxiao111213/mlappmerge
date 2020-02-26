function [loadOutcome, loadedData] = saveAppCode(filepath, code)   
    % Assume load will be successful
    loadOutcome.Status = 'success';
    loadedData = struct.empty;

   import appdesigner.internal.serialization.validator.deserialization.*;
           validators = {...
            
        ... Data Integrity
        MLAPPReleaseValidator, ...
        MLAPPTypeValidator, ...
        MLAPPResponsiveAppValidator ...
        ... Environment
        MLAPPLicenseValidator ...
        
        };
     % create a deserializer and get the app Data
    deserializer = appdesigner.internal.serialization.MLAPPDeserializer(filepath, validators);
    loadedData = deserializer.getAppData();
    
    
    fileWriter = appdesigner.internal.serialization.FileWriter(filepath);

    fileWriter.writeMATLABCodeText(code);
    loadOutcome.Status ='updated here 7';
end
