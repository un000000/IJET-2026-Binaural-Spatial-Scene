function [sig] = normalize_loudness(sig, fs, targetLoudness)
    dRL = limiter(-0.915);
    loudness = integratedLoudness(sig, fs);

    while abs(loudness - targetLoudness) > 0.001
        gain   = 10^((targetLoudness - loudness)/20);
        sig    = sig .* gain;
        sig    = dRL(sig);
        loudness = integratedLoudness(sig, fs);
    end
end