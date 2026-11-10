#include "EthGetworkClient.h"

#include <chrono>

#include <ethash/ethash.hpp>

using namespace std;
using namespace dev;
using namespace eth;

using boost::asio::ip::tcp;
using namespace boost::placeholders;   // for _1, _2, etc. on modern Boost

EthGetworkClient::EthGetworkClient(int worktimeout, unsigned farmRecheckPeriod)
  : PoolClient(),
    m_farmRecheckPeriod(farmRecheckPeriod),
    m_io_strand(g_io_service),
    m_socket(g_io_service),
    m_resolver(g_io_service),
    m_endpoints(),
    m_getwork_timer(g_io_service),
    m_worktimeout(worktimeout)
{
    m_jSwBuilder.settings_["indentation"] = "";

    Json::Value jGetWork;
    jGetWork["id"] = unsigned(1);
    jGetWork["jsonrpc"] = "2.0";
    jGetWork["method"] = "eth_getWork";
    jGetWork["params"] = Json::Value(Json::arrayValue);
    m_jsonGetWork = std::string(Json::writeString(m_jSwBuilder, jGetWork));
}

// ... rest of file unchanged (the using directive above fixes the _1 error)
