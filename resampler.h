#ifndef RESAMPLE_H
#define RESAMPLE_H

#include <vector>
#include <stdexcept>
#include <algorithm>
#include <limits>

#include <samplerate.h>

constexpr short float_to_short(float val)
{
    if (val < 0.0f)
    {
        const short min_short = std::numeric_limits<short>::min();
        return std::max(min_short, static_cast<short>(-val * min_short));
    }
    else
    {
        const short max_short = std::numeric_limits<short>::max();
        return std::min(max_short, static_cast<short>(val * max_short));
    }
}

constexpr float short_to_float(short val)
{
    if (val < 0)
    {
        return static_cast<float>(-val) / std::numeric_limits<short>::min();
    }
    else
    {
        return static_cast<float>(val) / std::numeric_limits<short>::max();
    }
}

class resampler
{
public:
    resampler(int converter_type, int channels)
        : m_source_rate(0),
          m_dest_rate(0)
    {
        static_assert(float_to_short(1.0f) == std::numeric_limits<short>::max(), "");
        static_assert(float_to_short(-1.0f) == std::numeric_limits<short>::min(), "");
        static_assert(float_to_short(0.0f) == 0, "");
        static_assert(float_to_short(-0.5f) == -16384, "");

        static_assert(short_to_float(std::numeric_limits<short>::max()) == 1.0f, "");
        static_assert(short_to_float(std::numeric_limits<short>::min()) == -1.0f, "");
        static_assert(short_to_float(0) == 0.0f, "");
        static_assert(short_to_float(-16384) == -0.5f, "");

        int err = 0;
        m_state = src_new(converter_type, channels, &err);
        if (m_state == nullptr)
        {
            throw std::runtime_error("Could not initialize sample converter");
        }
    }
    ~resampler()
    {
        src_delete(m_state);
    }

    void set_sample_rates(uint source_rate, uint dest_rate)
    {
        m_source_rate = source_rate;
        m_dest_rate = dest_rate;
    }

    void enqueue(const float* data, size_t count)
    {
        if (count == 0)
        {
            return;
        }
        else if (m_source_rate == m_dest_rate)
        {
            m_resampled_data.insert(m_resampled_data.end(), data, data + count);
        }
        else
        {
            m_data_to_resample.insert(m_data_to_resample.end(), data, data + count);

            do_resample();
        }
    }

    void enqueue(const short* data, size_t count)
    {
        if (count == 0)
        {
            return;
        }
        else if (m_source_rate == m_dest_rate)
        {
            const size_t prev_size = m_resampled_data.size();
            m_resampled_data.resize(prev_size + count);
            std::transform(data,
                           data + count,
                           m_resampled_data.begin() + prev_size,
                           short_to_float);
        }
        else
        {
            const size_t prev_size = m_data_to_resample.size();
            m_data_to_resample.resize(prev_size + count);
            std::transform(data,
                           data + count,
                           m_data_to_resample.begin() + prev_size,
                           short_to_float);

            do_resample();
        }
    }

    bool dequeue(float* data, size_t count)
    {
        if (count == 0)
        {
            return true;
        }
        else if (count <= available_elems())
        {
            const auto cend = m_resampled_data.cbegin() + count;
            std::copy(m_resampled_data.cbegin(), cend, data);
            m_resampled_data.erase(m_resampled_data.cbegin(), cend);
            return true;
        }
        else
        {
            return false;
        }
    }

    bool dequeue(short* data, size_t count)
    {
        if (count == 0)
        {
            return true;
        }
        else if (count <= available_elems())
        {
            const auto cend = m_resampled_data.cbegin() + count;
            std::transform(m_resampled_data.cbegin(), cend, data, float_to_short);
            m_resampled_data.erase(m_resampled_data.cbegin(), cend);
            return true;
        }
        else
        {
            return false;
        }
    }

    size_t available_elems() const
    {
        return m_resampled_data.size();
    }

private:

    void do_resample()
    {
        const uint max_output_frames = 
            ((m_data_to_resample.size() * m_dest_rate) / m_source_rate) + 1;

        const size_t prev_resampled_size = m_resampled_data.size();

        m_resampled_data.resize(prev_resampled_size + max_output_frames);

        SRC_DATA resample_parms;
        resample_parms.data_in = m_data_to_resample.data();
        resample_parms.data_out = m_resampled_data.data() + prev_resampled_size;

        resample_parms.input_frames = m_data_to_resample.size();
        resample_parms.output_frames = max_output_frames;

        resample_parms.end_of_input = 0;

        resample_parms.src_ratio = (double)m_dest_rate / (double)m_source_rate;

        if (src_process(m_state, &resample_parms) != 0)
        {
            throw std::runtime_error("Error resampling data");
            return;
        }

        if (resample_parms.output_frames_gen < resample_parms.output_frames)
        {
            const size_t valid_samples =
                prev_resampled_size + resample_parms.output_frames_gen;
            m_resampled_data.erase(m_resampled_data.begin() + valid_samples,
                                   m_resampled_data.end());
        }

        m_data_to_resample.erase(m_data_to_resample.begin(),
                                 m_data_to_resample.begin() + resample_parms.input_frames_used);
    }

private:
    uint m_source_rate;
    uint m_dest_rate;

    std::vector<float> m_data_to_resample;
    std::vector<float> m_resampled_data;

    SRC_STATE* m_state;
};

#endif
