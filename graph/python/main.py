# Google Cloud plotting function - provided as-is

# Data should be passed in a POST request as json.

# Return value is in text format:
#      if it starts with 'ERROR:' then an error occurred
#      if it starts with 'gs://' it is the URL for the image file

# IMPORTANT NOTE: You must set the name of a storage bucket in   
# in the first line of code after the import statements:
# bucket_name = 'eades_msvcs'
# The function will not work if you do not have a storage bucket
# on GCP called eades_msvcs.

# Data format for bar plot with 3 bars (any number can be plotted).
# Configurable values:
#
# filename
# x
# y
# ylab
#
# {"filename":"aname.png", "plottype":"line", "x":["one", "two", "three"], "y":["10", "8", "15"], "ylab":"number word counts"}

# Data format for line plot with two lines, each with 5 points
# (any number of lines or points can be plotted but all lines
# have to have the same number of points). Configurable values:
#
# filename
# x
# y
# ylab 
#
# {"filename":"aname.png", "plottype":"line", "x":["1", "2", "3", "4", "5"], "y":["10", "8", "6", "15", "22", "0", "10", "8", "6", "15"], "ylab":["first line", "second line"]}


def test_make_graph(rqst):

    import io
    import matplotlib.pyplot as plt
    import numpy as np
    from google.cloud import storage
    from urllib import request

    bucket_name = 'bk-eads-ca-bucket'
    plt.clf()

    
    request_json = rqst.get_json()
    if request_json:
        if 'filename' in request_json:
            if 'plottype' in request_json:
                if 'x' in request_json and 'y' in request_json:
                    x = request_json['x']
                    y = np.array(request_json['y']).astype(np.float)

                    if request_json['plottype'] == 'bar':
                        if len(x) == len(y):
                            positions = range(len(x))
                            plt.xticks(positions, x)
                            plt.bar(positions, y)
                            if 'ylab' in request_json:
                                if type(request_json['ylab']) is str:
                                    plt.ylabel(request_json['ylab'])
                                else:
                                    return f'ERROR: Y label is not a string'
                        else:
                            return f'ERROR: X and Y data not the same length'

                    elif request_json['plottype'] == 'line':
                        xlen = len(x)
                        ylen = len(y)
                        if xlen != 0 and ylen != 0:
                            if ylen % xlen == 0:
                                numLines = ylen/xlen
                                ylab = None
                                if 'ylab' in request_json:
                                    ylab = request_json['ylab']
                                    if numLines == 1:
                                        if type(ylab) is str:
                                            ylab = [ ylab ]
                                        elif not type(ylab) is list:
                                            return f'ERROR: Y label is not a string or a list'
                                    elif not type(ylab) is list:
                                        return f'ERROR: Y label is not a list'
                                        
                                ynp = np.array(y)
                                if ylab != None:
                                    for i in range(ylen//xlen):
                                        plt.plot(x, ynp[i*xlen:(i+1)*xlen], label=ylab[i])
                                    plt.legend()
                                else:
                                    plt.plot(x, ynp[i*xlen:(i+1)*xlen])
                            else:
                                return f'ERROR: Length of X or Y data is 0'
                        else:
                            return f'ERROR: Length of Y data is not a multiple of the length of X data'

                    else:
                        return f'ERROR: Unknown plot type'
                        
                    buf = io.BytesIO()
                    plt.savefig(buf, format='png')
                    
                    storageClient = storage.Client()
                    bucket = storageClient.get_bucket(bucket_name) 
                    blob = bucket.blob(request_json['filename'])
                    
                    if not blob.exists():
                        blob.upload_from_string(buf.getvalue(), content_type='image/png')
                        retVal = "gs://" + bucket_name + "/" + blob.name 
                    else:
                        return f'ERROR: File exists'
                        
                    buf.close()
                    return retVal

                else:
                    return f'ERROR: X or Y or both data not specified'
            else:
                return f'ERROR: Plot type not specified'
        else:
            return f'ERROR: File name not specified'
    else:
        return f'ERROR: Data not specified'

       
