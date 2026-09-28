clear();
clc();

addpath('./SOFAtoolbox')
addpath('./SOFAtoolbox/sofa_conventions')
addpath('./SOFAtoolbox/sofa_conventions\conventions')
addpath('./SOFAtoolbox/SOFAtoolbox')
addpath('./SOFAtoolbox/SOFAtoolbox/conventions')
addpath('./SOFAtoolbox/SOFAtoolbox/netcdf')
addpath('')
addpath('./test')

synthesize_all_audio('config_rooms.json', 'config_sources.json', "D:\KW\ALL_NONSPEECH_NONMUSIC_PROCESSED_sample", 'E:\\KW\\ALL_NONSPEECH_NONMUSIC_PROCESSED_SPATIALIZED');
