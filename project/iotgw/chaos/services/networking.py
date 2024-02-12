from main import mqtt
import asyncio


@mqtt.subscribe("gateway/chaos/disable/set")
async def disable_internet(client, topic, payload, qos, properties):
    print("Received message to specific topic: ", topic, payload.decode(), qos, properties)
    await asyncio.sleep(5)
    print("Done!")


@mqtt.subscribe("kpi/bed/chaos/disable/set")
async def disable_eth(client, topic, payload, qos, properties):
    print("Received message to specific topic: ", topic, payload.decode(), qos, properties)
    await asyncio.sleep(5)
    print("Done!")


@mqtt.subscribe("my/mqtt/topic/#")
async def disable_wn(client, topic, payload, qos, properties):
    print("Received message to specific topic: ", topic, payload.decode(), qos, properties)
    await asyncio.sleep(5)
    print("Done!")